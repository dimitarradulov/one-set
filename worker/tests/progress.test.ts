import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportSPKI, SignJWT } from 'jose';
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { handleProgressRequest } from '../src/progress.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = { CLERK_ISSUER: issuer, CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test' };
async function token(subject = 'user_a') {
  return new SignJWT({ sid: `session-${subject}` }).setProtectedHeader({ alg: 'RS256' })
    .setSubject(subject).setIssuer(issuer).setIssuedAt().setNotBefore('0s').setExpirationTime('1m')
    .sign(keys.privateKey);
}
function request(bearer?: string) {
  return new Request('https://api.oneset.test/v1/me/progress', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}
const db = new PGlite();
const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await db.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await db.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await db.exec(`INSERT INTO workout_programs (id, name) VALUES (10, 'Machine Full Body');`);
await db.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/011_catalog_repository_sync.sql', 'utf8'));
await db.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await db.exec(`INSERT INTO workouts (id, name, authoring_key) VALUES (100, 'A', 'day-a'), (101, 'B', 'day-b');
  INSERT INTO program_workouts (program_id, workout_id, position) VALUES (10, 100, 1), (10, 101, 2);
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES (1, 'user_a', 'kg', 3), (2, 'user_b', 'kg', 3);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 10, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  UPDATE users SET active_user_program_id = '22222222-2222-4222-8222-222222222222' WHERE id = 2;`);
await db.exec(await readFile('../docs/database/migrations/005_cycle_workout_boundaries.sql', 'utf8'));
const database = { query: async (sql: string, params: string[]) => (await db.query<Record<string, unknown>>(sql, params)).rows };

after(async () => { await db.close(); });

test('progress restore returns owned boundary, marks, and workout membership without session content', async () => {
  await db.exec(`UPDATE user_programs SET current_training_week = 9 WHERE id = '11111111-1111-4111-8111-111111111111';
    INSERT INTO completed_workouts (user_program_id, week_number, workout_id) VALUES
      ('11111111-1111-4111-8111-111111111111', 9, 100);`);
  const response = await handleProgressRequest(request(await token()), env, database);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await response.json(), {
    progress: {
      cycle_id: '11111111-1111-4111-8111-111111111111',
      program_id: 'machine-full-body', current_training_week: 9,
      completed_occurrences: [{ week_number: 9, workout_id: 'day-a' }],
      workout_periods: [
        { workout_id: 'day-a', starts_week: 1, ends_week: null },
        { workout_id: 'day-b', starts_week: 1, ends_week: null },
      ],
      required_workouts: ['day-a', 'day-b'],
    },
  });
  const sessionRows = await db.query(`SELECT count(*)::integer AS count FROM workout_sessions`);
  assert.deepEqual(sessionRows.rows, [{ count: 0 }]);
});

test('progress read requires authentication and returns no other account state', async () => {
  const unauthenticated = await handleProgressRequest(request(), env, database);
  assert.equal(unauthenticated.status, 401);
  const other = await handleProgressRequest(request(await token('user_b')), env, database);
  assert.deepEqual(await other.json(), { progress: {
    cycle_id: '22222222-2222-4222-8222-222222222222', program_id: 'machine-full-body',
    current_training_week: 1, completed_occurrences: [],
    workout_periods: [
      { workout_id: 'day-a', starts_week: 1, ends_week: null },
      { workout_id: 'day-b', starts_week: 1, ends_week: null },
    ], required_workouts: ['day-a', 'day-b'],
  } });
});

test('owned noncurrent cycle progress is available without exposing another account', async () => {
  await db.exec(`INSERT INTO user_programs (id, user_id, workout_program_id, started_at, current_training_week)
    VALUES ('33333333-3333-4333-8333-333333333333', 1, 10, now() - interval '1 day', 4)`);
  const own = new Request('https://api.oneset.test/v1/me/progress?cycle_id=33333333-3333-4333-8333-333333333333', {
    headers: { Authorization: `Bearer ${await token()}` },
  });
  const response = await handleProgressRequest(own, env, database);
  assert.equal((await response.json() as { progress: { cycle_id: string } }).progress.cycle_id,
    '33333333-3333-4333-8333-333333333333');
  const foreign = new Request('https://api.oneset.test/v1/me/progress?cycle_id=33333333-3333-4333-8333-333333333333', {
    headers: { Authorization: `Bearer ${await token('user_b')}` },
  });
  assert.deepEqual(await (await handleProgressRequest(foreign, env, database)).json(), { progress: null });
  const invalid = new Request('https://api.oneset.test/v1/me/progress?cycle_id=invalid', {
    headers: { Authorization: `Bearer ${await token()}` },
  });
  assert.equal((await handleProgressRequest(invalid, env, database)).status, 400);
});
