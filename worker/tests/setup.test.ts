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
await db.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
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
  SELECT setval(pg_get_serial_sequence('users', 'id'), 2);
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
  await db.exec(`INSERT INTO users (clerk_user_id, preferred_unit, training_days, active_user_program_id)
    VALUES ('user_cross', 'kg', 3, '22222222-2222-4222-8222-222222222222')`);
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

function saveRequest(bearer: string, body: unknown) {
  return new Request('https://api.oneset.test/v1/me/setup', {
    method: 'PUT', headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}
const completedSetup = {
  preferred_unit: 'lb', training_days: 4, program_id: 'machine-full-body',
  cycle_id: '33333333-3333-4333-8333-333333333333',
};
test('completed setup persists and retries return the same cycle through lookup', async () => {
  const bearer = await token('user_save');
  for (let attempt = 0; attempt < 2; attempt++) {
    const saved = await handleSetupRequest(saveRequest(bearer, completedSetup), env, database);
    assert.equal(saved.status, 200);
    assert.deepEqual(await saved.json(), { setup: completedSetup });
  }
  const restored = await handleSetupRequest(request(bearer), env, database);
  assert.deepEqual(await restored.json(), { setup: completedSetup });
});

test('delayed completion preserves established settings and all training state', async () => {
  const response = await handleSetupRequest(saveRequest(await token('user_b'), completedSetup), env, database);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { setup: {
    preferred_unit: 'kg', training_days: 2, program_id: 'machine-full-body',
    cycle_id: '22222222-2222-4222-8222-222222222222',
  } });
});

test('concurrent completions and interrupted acknowledgments create a single cycle', async () => {
  const bearer = await token('user_race');
  const body = { ...completedSetup, cycle_id: '44444444-4444-4444-8444-444444444444' };
  const responses = await Promise.all(Array.from({ length: 4 }, () =>
    handleSetupRequest(saveRequest(bearer, body), env, database)));
  for (const response of responses) {
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { setup: body });
  }
  // Lose a successful save response and retry with a competing device identity.
  const retried = await handleSetupRequest(saveRequest(bearer, completedSetup), env, database);
  assert.deepEqual(await retried.json(), { setup: body });
  const { rows } = await db.query(`SELECT count(*)::integer AS cycles FROM user_programs
    WHERE user_id = (SELECT id FROM users WHERE clerk_user_id = 'user_race')`);
  assert.deepEqual(rows, [{ cycles: 1 }]);
});

test('save rejects forged ownership, invalid bodies and authentication', async () => {
  for (const body of [{ ...completedSetup, user_id: 'user_b' },
    { ...completedSetup, training_days: 6 }, { ...completedSetup, program_id: 'unknown' },
    { ...completedSetup, cycle_id: 'bad' }, null]) {
    const response = await handleSetupRequest(saveRequest(await token('user_invalid_save'), body), env, database);
    assert.equal(response.status, 400);
  }
  const unauthenticated = await handleSetupRequest(saveRequest('invalid', completedSetup), env, database);
  assert.equal(unauthenticated.status, 401);
});

test('cycle identity collision rolls back completion without altering its owner', async () => {
  const body = { ...completedSetup, cycle_id: '22222222-2222-4222-8222-222222222222' };
  const bearer = await token('user_collision');
  const saved = await handleSetupRequest(saveRequest(bearer, body), env, database);
  assert.equal(saved.status, 503);
  const restored = await handleSetupRequest(request(bearer), env, database);
  assert.deepEqual(await restored.json(), { setup: null });
});
