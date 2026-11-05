import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, SignJWT, type JWTVerifyGetKey } from 'jose';
import { handleCatalogRequest, type CatalogDatabase } from '../src/catalog.ts';

const issuer = 'https://oneset-test.cloudflareaccess.com';
const audience = 'dashboard-test-audience';
const founder = 'founder@example.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const otherKeys = await generateKeyPair('RS256', { extractable: true });
const controlledKeySource: JWTVerifyGetKey = async () => keys.publicKey;
const source = {
  exercises: [{
    key: 'test-exercise', name: 'Test Exercise', instructions: 'Technique guidance.',
    stopping_guidance: 'Stop safely.', warmup_guidance: 'Warm up first.', rest_seconds: 90,
    default_reps: { minimum: 6, maximum: 10 },
  }],
  programs: [{
    key: 'test-program', name: 'Test Program', recommended_weeks: 8,
    format: 'A / B', emphasis: 'A test program.', removed: true,
    workouts: [{
      key: 'test-workout', name: 'Workout A', position: 1, removed: true,
      exercises: [{ key: 'test-slot', exercise: 'test-exercise', position: 1,
        reps: { minimum: 6, maximum: 10 }, removed: true }],
    }],
  }],
};
const database: CatalogDatabase = {
  query: async () => [{
    publication_id: 'publication-123', source_fingerprint: 'a'.repeat(64), source_document: source,
  }],
  transaction: async () => [],
};
const environment = {
  CLERK_ISSUER: 'https://clerk.example.test', CLERK_JWT_KEY: '', CLERK_AUTHORIZED_PARTIES: '',
  CATALOG_PUBLISH_TOKEN: '', ACCESS_TEAM_DOMAIN: issuer,
  ACCESS_AUDIENCE: audience, ACCESS_APPROVED_EMAIL: founder,
};

async function token(options: {
  signer?: typeof keys.privateKey;
  issuer?: string;
  audience?: string;
  email?: string;
  expires?: string;
} = {}): Promise<string> {
  return new SignJWT({ email: options.email ?? founder })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(options.issuer ?? issuer).setAudience(options.audience ?? audience)
    .setIssuedAt().setExpirationTime(options.expires ?? '1m')
    .sign(options.signer ?? keys.privateKey);
}

async function read(candidate?: string, db = database): Promise<Response> {
  return handleCatalogRequest(new Request('https://api.test/v1/maintenance/catalog/source', {
    headers: candidate ? { 'Cf-Access-Jwt-Assertion': candidate } : {},
  }), environment, db, controlledKeySource);
}

test('maintenance source read returns complete source and publication identity to the signed-in founder', async () => {
  const response = await read(await token());
  assert.equal(response.status, 200);
  const result = await response.json() as { source: typeof source; publication_id: string; source_fingerprint: string };
  assert.equal(result.publication_id, 'publication-123');
  assert.equal(result.source_fingerprint, 'a'.repeat(64));
  assert.equal(result.source.programs[0]?.removed, true);
  assert.equal(result.source.programs[0]?.workouts[0]?.removed, true);
  assert.equal(result.source.programs[0]?.workouts[0]?.exercises[0]?.removed, true);
  assert.match(response.headers.get('Cache-Control') ?? '', /no-store/);
});

test('maintenance source read rejects missing tokens, bad signatures, wrong issuer or audience, expiration, and other email', async () => {
  const cases = [
    await read(),
    await read(await token({ signer: otherKeys.privateKey })),
    await read(await token({ issuer: 'https://wrong.cloudflareaccess.com' })),
    await read(await token({ audience: 'other-app' })),
    await read(await token({ expires: '0s' })),
    await read(await token({ email: 'someone-else@example.test' })),
  ];
  for (const response of cases) assert.equal(response.status, 401);
});

test('maintenance source read rejects ordinary Clerk user tokens', async () => {
  const clerkToken = await new SignJWT({ sid: 'clerk-session' })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(environment.CLERK_ISSUER).setSubject('user_123')
    .setIssuedAt().setExpirationTime('1m').sign(keys.privateKey);
  assert.equal((await read(clerkToken)).status, 401);
});

test('maintenance source read reports unavailable storage instead of an empty catalog', async () => {
  const unavailable: CatalogDatabase = {
    query: async () => { throw new Error('simulated database outage'); },
    transaction: async () => [],
  };
  const response = await read(await token(), unavailable);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: { code: 'CATALOG_UNAVAILABLE' } });
});
