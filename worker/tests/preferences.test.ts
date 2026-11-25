import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportSPKI, SignJWT } from 'jose';
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { handlePreferencesRequest, type PreferencesDatabase } from '../src/preferences.ts';
import { handleSetupRequest, type SetupDatabase, type SetupConfiguration } from '../src/setup.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
  CLERK_SECRET_KEY: 'sk_test',
};
async function token(subject = 'user_a', claims = {}, signingKey = keys.privateKey) {
  return new SignJWT({ sid: 'sess_test', ...claims })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: 'test' })
    .setSubject(subject).setIssuer(issuer).setIssuedAt()
    .setNotBefore('0s').setExpirationTime('1m').sign(signingKey);
}
function patch(bearer: string | undefined, body: unknown, query = '') {
  return new Request('https://api.oneset.test/v1/me' + query, {
    method: 'PATCH',
    headers: { ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}), 'Content-Type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}
const valid = { preferred_unit: 'lb', training_days: 4 };

const db = new PGlite();
const migration = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await db.exec('BEGIN;\n' + migration.slice(migration.indexOf('CREATE TYPE')));
await db.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
const database: SetupDatabase & PreferencesDatabase = {
  query: async (sql, params) => (await db.query<Record<string, unknown>>(sql, params)).rows,
  transaction: async () => { throw new Error('unexpected erasure'); },
};
await db.exec(`
  INSERT INTO workout_programs (id, name) VALUES (10, 'Machine Full Body');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'user_a', 'kg', 3), (2, 'user_b', 'kg', 2), (3, 'user_unfinished', 'kg', 3);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 10, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  UPDATE users SET active_user_program_id = '22222222-2222-4222-8222-222222222222' WHERE id = 2;
`);
await db.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/011_catalog_repository_sync.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
after(async () => { await db.close(); });

const userRow = async (id: string) =>
  (await db.query(`SELECT preferred_unit, training_days FROM users WHERE clerk_user_id = $1`, [id])).rows[0];
const handle = (request: Request, database_: PreferencesDatabase = database) =>
  handlePreferencesRequest(request, env, database_);

test('a verified owner saves both values and receives them back, privately', async () => {
  const response = await handle(patch(await token('user_a'), valid));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await response.json(), valid);
  assert.deepEqual(await userRow('user_a'), valid);
});

test('ownership comes only from the verified subject, never a client claim', async () => {
  const before = await userRow('user_b');
  const response = await handle(patch(await token('user_a'),
    { preferred_unit: 'kg', training_days: 5 }, '?user_id=user_b'));
  assert.equal(response.status, 200);
  assert.deepEqual(await userRow('user_b'), before);
  const forged = await handle(patch(await token('user_a'), { ...valid, user_id: 'user_b' }));
  assert.equal(forged.status, 400);
  assert.deepEqual(await userRow('user_b'), before);
});

test('missing or invalid credentials never reach the database', async () => {
  const otherKeys = await generateKeyPair('RS256');
  const bearers = [undefined, 'invalid', await token('user_a', {}, otherKeys.privateKey),
    await token('user_a', { azp: 'https://untrusted.test' }), await token('user_a', { sts: 'pending' })];
  for (const bearer of bearers) {
    const response = await handle(patch(bearer, valid), {
      query: async () => { assert.fail('unauthenticated requests must not access the database'); },
    });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: { code: 'AUTH_REQUIRED' } });
  }
});

test('missing authentication configuration is a temporary failure', async () => {
  const response = await handlePreferencesRequest(patch(await token(), valid),
    { ...env, CLERK_JWT_KEY: '' }, database);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: { code: 'TEMPORARY_FAILURE' } });
});

test('invalid bodies return INVALID_SETTINGS without changing the account', async () => {
  const before = await userRow('user_a');
  const bodies: unknown[] = [
    { preferred_unit: 'lb' }, { training_days: 3 }, {},
    { ...valid, program_id: 'machine-full-body' },
    { preferred_unit: 'stone', training_days: 3 }, { preferred_unit: 'KG', training_days: 3 },
    { preferred_unit: 'kg', training_days: 1 }, { preferred_unit: 'kg', training_days: 6 },
    { preferred_unit: 'kg', training_days: 3.5 }, { preferred_unit: 'kg', training_days: '3' },
    { preferred_unit: 'kg', training_days: null }, null, [], 'text', 5,
    '{not json', '', JSON.stringify({ ...valid, padding: 'x'.repeat(3000) }),
  ];
  for (const body of bodies) {
    const response = await handle(patch(await token('user_a'), body),
      { query: async () => { assert.fail('invalid bodies must not access the database'); } });
    assert.equal(response.status, 400, JSON.stringify(body));
    assert.equal(response.headers.get('cache-control'), 'private, no-store');
    assert.deepEqual(await response.json(), { error: { code: 'INVALID_SETTINGS' } });
  }
  assert.deepEqual(await userRow('user_a'), before);
});

test('an oversized body is rejected before parsing even without a Content-Length', async () => {
  const stream = new ReadableStream({ start(controller) {
    controller.enqueue(new TextEncoder().encode('{"preferred_unit":"kg","training_days":3,"x":"'));
    controller.enqueue(new TextEncoder().encode('x'.repeat(4096) + '"}'));
    controller.close();
  } });
  const request = new Request('https://api.oneset.test/v1/me', {
    method: 'PATCH', headers: { Authorization: `Bearer ${await token()}` },
    body: stream, duplex: 'half',
  } as RequestInit);
  assert.equal((await handle(request)).status, 400);
});

test('the latest saved values win and the follow-up lookup returns them', async () => {
  const bearer = await token('user_b');
  for (const body of [{ preferred_unit: 'lb', training_days: 5 }, { preferred_unit: 'kg', training_days: 4 },
    { preferred_unit: 'lb', training_days: 2 }]) {
    const response = await handle(patch(bearer, body));
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), body);
  }
  const lookup = await handleSetupRequest(new Request('https://api.oneset.test/v1/me/setup', {
    headers: { Authorization: `Bearer ${bearer}` },
  }), env as SetupConfiguration, database, { getClerkUser: async () => ({ status: 'success' }) });
  assert.deepEqual(await lookup.json(), { setup: {
    preferred_unit: 'lb', training_days: 2, program_id: 'machine-full-body',
    cycle_id: '22222222-2222-4222-8222-222222222222',
  } });
});

test('repeating the same values succeeds and leaves the account unchanged', async () => {
  const bearer = await token('user_a');
  const first = await handle(patch(bearer, valid));
  const second = await handle(patch(bearer, valid));
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.deepEqual(await second.json(), valid);
});

test('an account without completed setup returns SETUP_REQUIRED and is not changed', async () => {
  const unfinished = await handle(patch(await token('user_unfinished'), valid));
  assert.equal(unfinished.status, 409);
  assert.equal(unfinished.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await unfinished.json(), { error: { code: 'SETUP_REQUIRED' } });
  assert.deepEqual(await userRow('user_unfinished'), { preferred_unit: 'kg', training_days: 3 });
  const unknown = await handle(patch(await token('user_never_seen'), valid));
  assert.equal(unknown.status, 409);
  assert.equal(await userRow('user_never_seen'), undefined, 'PATCH never creates an account');
});

test('database failure returns TEMPORARY_FAILURE', async () => {
  const response = await handle(patch(await token('user_a'), valid),
    { query: async () => { throw new Error('offline'); } });
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await response.json(), { error: { code: 'TEMPORARY_FAILURE' } });
});

test('only PATCH is handled by this route', async () => {
  const response = await handle(new Request('https://api.oneset.test/v1/me', {
    method: 'POST', headers: { Authorization: `Bearer ${await token()}` },
  }));
  assert.equal(response.status, 405);
});
