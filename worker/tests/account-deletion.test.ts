import { test, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { cleanupSubscription, handleAccountDeletionRequest, type AccountDeletionServices } from '../src/account-deletion.ts';
import type { ClerkUserResult } from '../src/clerk-users.ts';
import { handleSetupRequest } from '../src/setup.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
  CLERK_SECRET_KEY: 'sk_test',
  REVENUECAT_PROJECT_ID: 'proj_test',
  REVENUECAT_SECRET_KEY: 'sk_rc_test',
};
async function token(subject = 'user_a') {
  return new SignJWT({ sid: 'sess_test' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: 'test' })
    .setSubject(subject).setIssuer(issuer).setIssuedAt()
    .setNotBefore('0s').setExpirationTime('1m').sign(keys.privateKey);
}
async function request(method = 'DELETE') {
  return new Request('https://api.oneset.test/v1/me', {
    method, headers: { Authorization: `Bearer ${await token()}` },
  });
}

type Statement = { query: string; params: string[] };

const db = new PGlite();
const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await db.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await db.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await db.exec(`INSERT INTO workout_programs (id, name) VALUES (10, 'Machine Full Body');`);
await db.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/011_catalog_repository_sync.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await db.exec(`INSERT INTO workouts (id, name, authoring_key) VALUES (100, 'A', 'day-a');`);
await db.exec(await readFile('../docs/database/migrations/005_cycle_workout_boundaries.sql', 'utf8'));

const events: string[] = [];
let failErasureWith: string | null = null;
const database = {
  transaction: async (statements: Statement[]) => {
    events.push('erase');
    await db.transaction(async tx => {
      for (const s of statements) await tx.query(s.query, s.params);
      if (failErasureWith) await tx.query(failErasureWith);
    });
  },
};

let clerkResults: ClerkUserResult[] = [];
const logs: unknown[] = [];
const services: AccountDeletionServices = {
  cleanupSubscription: async () => { events.push('hook'); },
  deleteClerkUser: async () => { events.push('clerk'); return clerkResults.shift() ?? { status: 'success' }; },
  log: entry => { logs.push(entry); },
};

async function count(table: string, where = '') {
  return Number((await db.query<{ n: number }>(`SELECT count(*)::int AS n FROM ${table} ${where}`)).rows[0].n);
}

beforeEach(async () => {
  events.length = 0; logs.length = 0; failErasureWith = null; clerkResults = [];
  await db.exec(`
    TRUNCATE users, user_programs, user_workout_exercises, workout_sessions,
      workout_session_sets, completed_workouts, user_program_workout_periods CASCADE;
    INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES (1, 'user_a', 'kg', 3), (2, 'user_b', 'kg', 3);
    INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
      ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
      ('22222222-2222-4222-8222-222222222222', 2, 10, now());
    UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
    UPDATE users SET active_user_program_id = '22222222-2222-4222-8222-222222222222' WHERE id = 2;
    SELECT setval(pg_get_serial_sequence('users', 'id'), 100);
    INSERT INTO completed_workouts (user_program_id, week_number, workout_id) VALUES
      ('11111111-1111-4111-8111-111111111111', 1, 100), ('22222222-2222-4222-8222-222222222222', 1, 100);
    INSERT INTO workout_sessions (id, user_program_id, workout_id, week_number, workout_name, started_at) VALUES
      ('33333333-3333-4333-8333-333333333333', '11111111-1111-4111-8111-111111111111', 100, 1, 'A', now()),
      ('44444444-4444-4444-8444-444444444444', '22222222-2222-4222-8222-222222222222', 100, 1, 'A', now());
  `);
});
after(async () => { await db.close(); });

const handle = (req: Request) => handleAccountDeletionRequest(req, env, database, services);

test('success erases only the caller and runs erase, hook, Clerk, sweep in order', async () => {
  const response = await handle(await request());
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await response.json(), { status: 'deleted' });
  assert.deepEqual(events, ['erase', 'hook', 'clerk', 'erase']);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_a'"), 0);
  assert.equal(await count('user_programs', 'WHERE user_id = 1'), 0);
  assert.equal(await count('workout_sessions', "WHERE id = '33333333-3333-4333-8333-333333333333'"), 0);
  assert.equal(await count('completed_workouts'), 1);
  assert.equal(await count('workout_sessions'), 1);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_b'"), 1);
});

test('a failing statement rolls back the whole erasure and returns 503', async () => {
  failErasureWith = 'SELECT 1/0';
  const response = await handle(await request());
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: { code: 'TEMPORARY_FAILURE' } });
  assert.equal(await count('users'), 2);
  assert.equal(await count('completed_workouts'), 2);
  assert.deepEqual(events, ['erase']);
});

test('a Clerk failure returns 503 and a repeat call completes the deletion', async () => {
  clerkResults = [{ status: 'temporaryFailure' }];
  const first = await handle(await request());
  assert.equal(first.status, 503);
  assert.deepEqual(await first.json(), { error: { code: 'TEMPORARY_FAILURE' } });
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_a'"), 0);
  const second = await handle(await request());
  assert.equal(second.status, 200);
});

test('a repeat call with no rows left still deletes the identity and treats Clerk 404 as success', async () => {
  await handle(await request());
  events.length = 0;
  clerkResults = [{ status: 'notFound' }];
  const response = await handle(await request());
  assert.equal(response.status, 200);
  assert.deepEqual(events, ['erase', 'hook', 'clerk', 'erase']);
});

test('a hook failure returns 503 before Clerk is called', async () => {
  const response = await handleAccountDeletionRequest(await request(), env, database, {
    ...services, cleanupSubscription: async () => { throw new Error('boom'); },
  });
  assert.equal(response.status, 503);
  assert.ok(!events.includes('clerk'));
});

test('a sweep failure is logged with the Clerk ID only and the deletion still succeeds', async () => {
  let calls = 0;
  const flaky = {
    transaction: async (statements: Statement[]) => {
      if (++calls === 2) throw new Error('database down');
      return database.transaction(statements);
    },
  };
  const response = await handleAccountDeletionRequest(await request(), env, flaky, services);
  assert.equal(response.status, 200);
  assert.deepEqual(logs, [{ event: 'account_deletion_sweep_failed', clerk_user_id: 'user_a' }]);
});

test('authentication and method errors use the existing shapes', async () => {
  const missing = await handle(new Request('https://api.oneset.test/v1/me', { method: 'DELETE' }));
  assert.equal(missing.status, 401);
  assert.deepEqual(await missing.json(), { error: { code: 'AUTH_REQUIRED' } });
  const wrongMethod = await handle(await request('GET'));
  assert.equal(wrongMethod.status, 405);
  assert.equal(await count('users'), 2);
});

test('a missing Clerk secret returns 503 without erasing', async () => {
  const response = await handleAccountDeletionRequest(await request(), { ...env, CLERK_SECRET_KEY: '' }, database, services);
  assert.equal(response.status, 503);
  assert.equal(await count('users'), 2);
});

test('race: a row a stale setup request inserts between the erase and the Clerk delete is gone after the sweep', async () => {
  const racing: AccountDeletionServices = { ...services, deleteClerkUser: async () => {
    events.push('clerk');
    await db.exec(`INSERT INTO users (clerk_user_id, preferred_unit, training_days) VALUES ('user_a', 'kg', 3)`);
    assert.equal(await count('users', "WHERE clerk_user_id = 'user_a'"), 1);
    return { status: 'success' };
  } };
  const response = await handleAccountDeletionRequest(await request(), env, database, racing);
  assert.equal(response.status, 200);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_a'"), 0);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_b'"), 1);
});

test('race: a stale setup request after the Clerk delete removes its own row and returns 401', async () => {
  await handle(await request());
  const response = await handleSetupRequest(
    new Request('https://api.oneset.test/v1/me/setup', { headers: { Authorization: `Bearer ${await token()}` } }),
    env,
    { ...database, query: async (sql, params) => (await db.query<Record<string, unknown>>(sql, params)).rows },
    { getClerkUser: async () => ({ status: 'notFound' }) },
  );
  assert.equal(response.status, 401);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_a'"), 0);
});

// RevenueCat answers each DELETE with the next queued status; Clerk calls are recorded by `services`.
function revenueCat(statuses: number[]) {
  const calls: string[] = [];
  const fetcher = (async (url: string | URL | Request) => {
    calls.push(String(url));
    events.push('revenuecat');
    return new Response('{}', { status: statuses.shift() ?? 200 });
  }) as typeof fetch;
  const withRevenueCat: AccountDeletionServices = {
    ...services,
    cleanupSubscription: clerkUserId => cleanupSubscription(clerkUserId, env, fetcher, services.log),
  };
  return { calls, services: withRevenueCat };
}

test('RevenueCat deletion runs after the erasure and before Clerk, for the caller only', async () => {
  const rc = revenueCat([200]);
  const response = await handleAccountDeletionRequest(await request(), env, database, rc.services);
  assert.equal(response.status, 200);
  assert.deepEqual(events, ['erase', 'revenuecat', 'clerk', 'erase']);
  assert.deepEqual(rc.calls, ['https://api.revenuecat.com/v2/projects/proj_test/customers/user_a']);
});

test('a RevenueCat failure returns 503 before Clerk, and a repeat attempt completes the deletion', async () => {
  const rc = revenueCat([503, 200]);
  const first = await handleAccountDeletionRequest(await request(), env, database, rc.services);
  assert.equal(first.status, 503);
  assert.deepEqual(await first.json(), { error: { code: 'TEMPORARY_FAILURE' } });
  assert.deepEqual(events, ['erase', 'revenuecat']);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_a'"), 0);
  assert.equal(await count('users', "WHERE clerk_user_id = 'user_b'"), 1);
  assert.deepEqual(logs, [{
    event: 'account_deletion_subscription_cleanup_failed', clerk_user_id: 'user_a', http_status: '503',
  }]);

  events.length = 0;
  const second = await handleAccountDeletionRequest(await request(), env, database, rc.services);
  assert.equal(second.status, 200);
  assert.deepEqual(events, ['erase', 'revenuecat', 'clerk', 'erase']);
});

test('a customer RevenueCat no longer has counts as deleted, so a repeat after success still finishes', async () => {
  const rc = revenueCat([404]);
  const response = await handleAccountDeletionRequest(await request(), env, database, rc.services);
  assert.equal(response.status, 200);
  assert.deepEqual(events, ['erase', 'revenuecat', 'clerk', 'erase']);
});

test('missing RevenueCat configuration returns 503 and never deletes the Clerk identity', async () => {
  const rc = revenueCat([200]);
  const unconfigured = { ...env, REVENUECAT_SECRET_KEY: '' };
  const response = await handleAccountDeletionRequest(await request(), unconfigured, database, {
    ...rc.services,
    cleanupSubscription: clerkUserId => cleanupSubscription(clerkUserId, unconfigured, undefined, services.log),
  });
  assert.equal(response.status, 503);
  assert.ok(!events.includes('clerk'));
});
