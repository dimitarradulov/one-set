import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportSPKI, SignJWT } from 'jose';
import type { ClerkUserResult } from '../src/clerk-users.ts';
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { handleSetupRequest as handleSetup, type SetupConfiguration, type SetupDatabase, type SetupServices } from '../src/setup.ts';

// Existing users and confirmed Clerk identities: the stale-token guard passes without erasing.
const handleSetupRequest = (request: Request, env: object, database: Pick<SetupDatabase, 'query'> & Partial<SetupDatabase>,
  services: SetupServices = { getClerkUser: async () => ({ status: 'success' }) }) =>
  handleSetup(request, { CLERK_SECRET_KEY: 'sk_test', ...env } as SetupConfiguration, {
    transaction: async () => { throw new Error('unexpected erasure'); }, ...database,
  }, services);


const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
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
  transaction: async statements => {
    await db.transaction(async tx => { for (const s of statements) await tx.query(s.query, s.params); });
  },
};
await db.exec(`
  INSERT INTO workout_programs (id, name) VALUES
    (1, 'Full Body'), (2, 'Upper / Lower'), (3, 'Push / Pull / Legs'),
    (4, 'Bro Split'), (5, 'Minimalist Full Body'), (6, 'V-Taper'),
    (7, 'Powerhouse'), (8, 'Classic Physique'),
    (9, 'Free-Weight Full Body'), (10, 'Machine Full Body');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'user_a', 'lb', 5), (2, 'user_b', 'kg', 2);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 10, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  UPDATE users SET active_user_program_id = '22222222-2222-4222-8222-222222222222' WHERE id = 2;
  SELECT setval(pg_get_serial_sequence('users', 'id'), 2);
`);
await db.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/011_catalog_repository_sync.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
// The erasure statements delete from this table; migration 005 itself is not needed here.
await db.exec(`CREATE TABLE public.user_program_workout_periods (
  user_program_id uuid NOT NULL REFERENCES public.user_programs(id) ON DELETE CASCADE)`);

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
  const { rows } = await db.query(`SELECT clerk_user_id, preferred_unit, training_days,
    active_user_program_id FROM users WHERE clerk_user_id = 'user_new'`);
  assert.deepEqual(rows, [{ clerk_user_id: 'user_new', preferred_unit: 'kg',
    training_days: 3, active_user_program_id: null }]);
  const cycles = await db.query(`SELECT id FROM user_programs
    WHERE user_id = (SELECT id FROM users WHERE clerk_user_id = 'user_new')`);
  assert.equal(cycles.rows.length, 0);
});

const clerk = (...results: ClerkUserResult[]) => {
  const calls: string[] = [];
  const services: SetupServices = { getClerkUser: async id => { calls.push(id); return results.shift() ?? { status: 'success' }; } };
  return { calls, services };
};
const userRows = async (id: string) => (await db.query(`SELECT id FROM users WHERE clerk_user_id = $1`, [id])).rows.length;

test('setup for an existing row makes no Clerk call', async () => {
  const { calls, services } = clerk({ status: 'notFound' });
  for (const method of ['GET', 'PUT']) {
    const bearer = await token('user_b');
    const req = method === 'GET' ? request(bearer) : saveRequest(bearer, completedSetup);
    assert.equal((await handleSetupRequest(req, env, database, services)).status, 200);
  }
  assert.deepEqual(calls, []);
});

test('a new row for a deleted Clerk user is erased and returns 401', async () => {
  const { calls, services } = clerk({ status: 'notFound' });
  const response = await handleSetupRequest(request(await token('user_gone')), env, database, services);
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: { code: 'AUTH_REQUIRED' } });
  assert.deepEqual(calls, ['user_gone']);
  assert.equal(await userRows('user_gone'), 0);
});

test('a failed Clerk check erases the new row and returns 503', async () => {
  const { services } = clerk({ status: 'temporaryFailure' });
  const response = await handleSetupRequest(request(await token('user_clerk_down')), env, database, services);
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: { code: 'TEMPORARY_FAILURE' } });
  assert.equal(await userRows('user_clerk_down'), 0);
});

test('a failed erase of an unconfirmed row is retried once and the rollback still happens', async () => {
  const { services } = clerk({ status: 'notFound' });
  let attempts = 0;
  const flaky: SetupDatabase = { ...database, transaction: async statements => {
    if (++attempts === 1) throw new Error('transient');
    return database.transaction(statements);
  } };
  const response = await handleSetupRequest(request(await token('user_erase_retry')), env, flaky, services);
  assert.equal(response.status, 401);
  assert.equal(attempts, 2);
  assert.equal(await userRows('user_erase_retry'), 0);
});

test('when the erase keeps failing the response is 503 and the row stays for the operator', async () => {
  const { services } = clerk({ status: 'notFound' });
  const broken: SetupDatabase = { ...database, transaction: async () => { throw new Error('down'); } };
  const response = await handleSetupRequest(request(await token('user_erase_fail')), env, broken, services);
  assert.equal(response.status, 503);
  assert.equal(await userRows('user_erase_fail'), 1);
});

test('a new row confirmed by Clerk is kept and the check runs once', async () => {
  const { calls, services } = clerk({ status: 'success' });
  const bearer = await token('user_real');
  assert.equal((await handleSetupRequest(request(bearer), env, database, services)).status, 200);
  assert.equal((await handleSetupRequest(request(bearer), env, database, services)).status, 200);
  assert.deepEqual(calls, ['user_real']);
  assert.equal(await userRows('user_real'), 1);
});

test('POST setup for a new user goes through the guarded insert before complete_onboarding', async () => {
  const order: string[] = [];
  const { services } = clerk({ status: 'notFound' });
  const spy: SetupDatabase = { ...database, query: async (sql, params) => {
    if (sql.includes('INSERT INTO users')) order.push('insert');
    if (sql.includes('complete_onboarding')) order.push('onboarding');
    return database.query(sql, params);
  } };
  const response = await handleSetupRequest(saveRequest(await token('user_new_post'), { ...completedSetup, cycle_id: '55555555-5555-4555-8555-555555555555' }), env, spy, services);
  assert.equal(response.status, 401);
  assert.deepEqual(order, ['insert']);
  assert.equal(await userRows('user_new_post'), 0);
  const ok = clerk({ status: 'success' });
  order.length = 0;
  const saved = await handleSetupRequest(saveRequest(await token('user_new_post'), { ...completedSetup, cycle_id: '55555555-5555-4555-8555-555555555555' }), env, spy, ok.services);
  assert.equal(saved.status, 200);
  assert.deepEqual(order.slice(0, 2), ['insert', 'onboarding']);
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
    const response = await handleSetupRequest(request(bearer), env, {
      query: async () => { assert.fail('unauthenticated requests must not access the database'); },
    });
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

test('concurrent first lookups create exactly one verified account and ignore client identity claims', async () => {
  const bearer = await token('user_concurrent');
  const responses = await Promise.all(Array.from({ length: 4 }, () =>
    handleSetupRequest(request(bearer, '?user_id=user_spoofed'), env, database)));
  for (const response of responses) {
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { setup: null });
  }
  const { rows } = await db.query(`SELECT clerk_user_id FROM users
    WHERE clerk_user_id IN ('user_concurrent', 'user_spoofed')`);
  assert.deepEqual(rows, [{ clerk_user_id: 'user_concurrent' }]);
});

test('repeat lookups preserve an unfinished account preferences and identity', async () => {
  const { rows: before } = await db.query(`INSERT INTO users
    (clerk_user_id, preferred_unit, training_days) VALUES ('user_unfinished', 'lb', 4)
    RETURNING *`);
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = await handleSetupRequest(request(await token('user_unfinished')), env, database);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { setup: null });
  }
  const { rows: after } = await db.query(`SELECT * FROM users WHERE clerk_user_id = 'user_unfinished'`);
  assert.deepEqual(after, before);
});

test('retry after lookup failure reuses the account created before the failure', async () => {
  const bearer = await token('user_retry');
  let queryCount = 0;
  const failed = await handleSetupRequest(request(bearer), env, {
    query: async (sql, params) => {
      if (++queryCount === 2) throw new Error('lookup unavailable');
      return database.query(sql, params);
    },
  });
  assert.equal(failed.status, 503);
  assert.deepEqual(await failed.json(), { error: { code: 'TEMPORARY_FAILURE' } });
  const { rows: before } = await db.query(`SELECT * FROM users WHERE clerk_user_id = 'user_retry'`);
  assert.equal(before.length, 1);
  const retried = await handleSetupRequest(request(bearer), env, database);
  assert.equal(retried.status, 200);
  assert.deepEqual(await retried.json(), { setup: null });
  const { rows: after } = await db.query(`SELECT * FROM users WHERE clerk_user_id = 'user_retry'`);
  assert.deepEqual(after, before);
});

test('database outage and unresolved program identities are failures, not evidence of a new account', async () => {
  const outage = await handleSetupRequest(request(await token()), env, {
    query: async () => { throw new Error('offline'); },
  });
  assert.equal(outage.status, 503);
  const unresolved = await handleSetupRequest(request(await token('user_unmapped')), env, {
    query: async sql => sql.trimStart().startsWith('SELECT') ? [{
      preferred_unit: 'kg', training_days: 3, active_user_program_id: '33333333-3333-4333-8333-333333333333',
      cycle_id: '33333333-3333-4333-8333-333333333333', workout_program_id: 99,
      program_id: null, has_cycles: true,
    }] : [],
  });
  assert.equal(unresolved.status, 503);
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
    { ...completedSetup, training_days: 6 }, { ...completedSetup, program_id: 'unknown space' },
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
