import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportSPKI, SignJWT } from 'jose';
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { handleSetupRequest, type SetupDatabase } from '../src/setup.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
  PROGRAM_CATALOG_MAP: '{"1":"machine-full-body"}',
};
async function token(subject = 'user_a', claims = {}, signingKey = keys.privateKey) {
  return new SignJWT({ sid: 'sess_test', ...claims })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: 'test' })
    .setSubject(subject).setIssuer(issuer).setIssuedAt()
    .setNotBefore('0s').setExpirationTime('1m').sign(signingKey);
}
function request(bearer?: string, query = '') {
  return new Request('https://api.oneset.test/v1/me/setup' + query, {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}
const db = new PGlite();
const migration = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
// Load the applied schema's CREATE statements, skipping the legacy replacement guard.
await db.exec('BEGIN;\n' + migration.slice(migration.indexOf('CREATE TYPE')));
const database: SetupDatabase = {
  query: async (sql, params) => (await db.query<Record<string, unknown>>(sql, params)).rows,
};
await db.exec(`
  INSERT INTO workout_programs (id, name) VALUES (1, 'Machine Full Body');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'user_a', 'lb', 5), (2, 'user_b', 'kg', 2);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 1, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 1, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  UPDATE users SET active_user_program_id = '22222222-2222-4222-8222-222222222222' WHERE id = 2;
`);

test('lookup returns only verified owner setup even with a client ownership claim', async () => {
  const response = await handleSetupRequest(request(await token(), '?user_id=user_b'), env, database);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await response.json(), { setup: {
    preferred_unit: 'lb', training_days: 5, program_id: 'machine-full-body',
    cycle_id: '11111111-1111-4111-8111-111111111111',
  } });
});

after(async () => { await db.close(); });

test('confirmed absence returns null for a new account', async () => {
  const response = await handleSetupRequest(request(await token('user_new')), env, database);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { setup: null });
});

test('invalid credentials never return private setup', async () => {
  const otherKeys = await generateKeyPair('RS256');
  const invalidTokens = [undefined, 'invalid',
    await token('user_a', {}, otherKeys.privateKey),
    await new SignJWT({sid:'sess_test'}).setProtectedHeader({alg:'RS256', typ:'JWT'}).setSubject('user_a').setIssuer('https://other.clerk.test').setIssuedAt().setNotBefore('0s').setExpirationTime('1m').sign(keys.privateKey),
    await new SignJWT({sid:'sess_test'}).setProtectedHeader({alg:'RS256', typ:'JWT'}).setSubject('user_a').setIssuer(issuer).setIssuedAt().setNotBefore('-2m').setExpirationTime('-1m').sign(keys.privateKey),
    await token('user_a', { azp: 'https://untrusted.test' }),
    await token('user_a', { sts: 'pending' }),
  ];
  for (const bearer of invalidTokens) {
    const response = await handleSetupRequest(request(bearer), env, database);
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: { code: 'AUTH_REQUIRED' } });
  }
});

test('a broken cross-account active-cycle link never exposes the other account setup', async () => {
  await db.exec(`INSERT INTO users (id, clerk_user_id, preferred_unit, training_days, active_user_program_id)
    VALUES (3, 'user_cross', 'kg', 3, '22222222-2222-4222-8222-222222222222')`);
  const response = await handleSetupRequest(request(await token('user_cross')), env, database);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: { code: 'SETUP_UNAVAILABLE' } });
});

test('database outage and unmapped programs are failures, not evidence of a new account', async () => {
  const outage = await handleSetupRequest(request(await token()), env, {
    query: async () => { throw new Error('offline'); },
  });
  assert.equal(outage.status, 503);
  const unmapped = await handleSetupRequest(request(await token()), { ...env, PROGRAM_CATALOG_MAP: '{}' }, database);
  assert.equal(unmapped.status, 503);
});

test('repeat lookups preserve established settings and cycle identity', async () => {
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await handleSetupRequest(request(await token('user_b')), env, database);
    assert.deepEqual(await response.json(), { setup: {
      preferred_unit: 'kg', training_days: 2, program_id: 'machine-full-body',
      cycle_id: '22222222-2222-4222-8222-222222222222',
    } });
  }
});
