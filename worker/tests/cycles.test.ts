import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportSPKI, SignJWT } from 'jose';
import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import { handleCycleRequest } from '../src/cycles.ts';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = { CLERK_ISSUER: 'https://clerk.test', CLERK_JWT_KEY: await exportSPKI(keys.publicKey), CLERK_AUTHORIZED_PARTIES: 'https://oneset.test' };
async function token(subject = 'user_a') { return new SignJWT({ sid: 'session' }).setProtectedHeader({ alg: 'RS256' }).setSubject(subject).setIssuer(env.CLERK_ISSUER).setIssuedAt().setExpirationTime('1m').sign(keys.privateKey); }
const engine = new PGlite();
const initial = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await engine.exec('BEGIN;\n' + initial.slice(initial.indexOf('CREATE TYPE')));
await engine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await engine.exec(`INSERT INTO workout_programs (id, name) VALUES (1, 'Full Body'), (2, 'Upper Lower'), (3, 'Removed');`);
for (const file of ['003_catalog_publication.sql', '004_offered_program_onboarding.sql', '005_cycle_workout_boundaries.sql', '008_cycle_creation.sql']) await engine.exec(await readFile('../docs/database/migrations/' + file, 'utf8'));
await engine.exec(`INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES (1, 'user_a', 'kg', 3), (2, 'user_b', 'lb', 4);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES ('11111111-1111-4111-8111-111111111111', 1, 1, '2026-01-01Z'), ('22222222-2222-4222-8222-222222222222', 2, 1, '2026-01-01Z');
  UPDATE users SET active_user_program_id = CASE id WHEN 1 THEN '11111111-1111-4111-8111-111111111111'::uuid ELSE '22222222-2222-4222-8222-222222222222'::uuid END;
  UPDATE workout_programs SET is_offered = false WHERE id = 3;`);
const database = { query: async (sql: string, params: string[]) => (await engine.query<Record<string, unknown>>(sql, params)).rows };
async function call(path: string, method = 'GET', body?: unknown, subject = 'user_a') { return handleCycleRequest(new Request('https://api.oneset.test' + path, { method, headers: { Authorization: `Bearer ${await token(subject)}` }, body: body === undefined ? undefined : JSON.stringify(body) }), env, database); }
after(async () => engine.close());
const cycle = { cycle_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', program_id: 'upper-lower', started_at: '2026-06-01T00:00:00.000Z' };
test('creation is durable and an equal retry does not reactivate an old choice', async () => {
  const created = await call('/v1/cycles', 'POST', cycle);
  assert.equal(created.status, 201);
  assert.deepEqual(await created.json(), { cycle_id: cycle.cycle_id, result: 'created' });
  await engine.exec(`UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1`);
  const retry = await call('/v1/cycles', 'POST', cycle);
  assert.equal(retry.status, 200);
  assert.deepEqual(await retry.json(), { cycle_id: cycle.cycle_id, result: 'acknowledged' });
  const lookup = await call('/v1/me/cycles');
  assert.deepEqual(await lookup.json(), { selected_cycle_id: '11111111-1111-4111-8111-111111111111', cycles: [
    { cycle_id: '11111111-1111-4111-8111-111111111111', program_id: 'full-body', started_at: '2026-01-01T00:00:00.000Z' }, cycle,
  ] });
});

test('ownership, existing programs, unavailable programs and malformed identities are rejected', async () => {
  const foreign = await call('/v1/cycles', 'POST', { ...cycle, cycle_id: '22222222-2222-4222-8222-222222222222', program_id: 'full-body', started_at: '2026-01-01T00:00:00.000Z' });
  assert.equal(foreign.status, 403);
  const duplicate = await call('/v1/cycles', 'POST', { ...cycle, cycle_id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' });
  assert.equal(duplicate.status, 409);
  assert.deepEqual(await duplicate.json(), { error: { code: 'CYCLE_CONFLICT' } });
  const removed = await call('/v1/cycles', 'POST', { ...cycle, cycle_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', program_id: 'push-pull-legs' });
  assert.equal(removed.status, 409);
  assert.deepEqual(await removed.json(), { error: { code: 'PROGRAM_UNAVAILABLE' } });
  const invalid = await call('/v1/cycles', 'POST', { ...cycle, cycle_id: 'not-a-uuid' });
  assert.equal(invalid.status, 400);
  const lookup = await call('/v1/me/cycles', 'GET', undefined, 'user_b');
  assert.deepEqual(await lookup.json(), { selected_cycle_id: '22222222-2222-4222-8222-222222222222', cycles: [{ cycle_id: '22222222-2222-4222-8222-222222222222', program_id: 'full-body', started_at: '2026-01-01T00:00:00.000Z' }] });
});

test('a failed insert rolls back the selection', async () => {
  await engine.exec(`CREATE FUNCTION fail_cycle_insert() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test failure'; END $$;
    CREATE TRIGGER reject_cycle BEFORE INSERT ON user_programs FOR EACH ROW EXECUTE FUNCTION fail_cycle_insert();`);
  const response = await call('/v1/cycles', 'POST', { ...cycle, cycle_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', program_id: 'bro-split' });
  // Program is missing, so insert a distinct offered program before testing rollback.
  assert.equal(response.status, 409);
  await engine.exec(`INSERT INTO workout_programs (id, name, authoring_key) VALUES (4, 'Bro Split', 'bro-split');`);
  const failed = await call('/v1/cycles', 'POST', { ...cycle, cycle_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', program_id: 'bro-split' });
  assert.equal(failed.status, 503);
  const { rows } = await engine.query<{ active_user_program_id: string }>(`SELECT active_user_program_id FROM users WHERE id = 1`);
  assert.equal(rows[0].active_user_program_id, '11111111-1111-4111-8111-111111111111');
  await engine.exec('DROP TRIGGER reject_cycle ON user_programs; DROP FUNCTION fail_cycle_insert();');
});

test('requests require authentication', async () => {
  const response = await handleCycleRequest(new Request('https://api.oneset.test/v1/me/cycles'), env, database);
  assert.equal(response.status, 401);
});

test('initial compatible preferences are created once and retries preserve later changes', async () => {
  await engine.exec(`INSERT INTO workouts (id, name, authoring_key) VALUES (1, 'Workout', 'test-workout');
    INSERT INTO exercises (id, name, authoring_key, instructions, reps_min, reps_max, rest_seconds, warmup_guidance) VALUES (1, 'Exercise', 'test-exercise', '', 5, 10, 60, '{}');
    INSERT INTO program_workouts (program_id, workout_id, position) VALUES (4, 1, 1);
    INSERT INTO workout_exercises (id, workout_id, exercise_id, position, reps_min, reps_max, authoring_key) VALUES (1, 1, 1, 1, 5, 10, 'test-slot');`);
  const body = { ...cycle, cycle_id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', program_id: 'bro-split', preferences: [{ workout_exercise_id: 'test-slot', exercise_id: 'test-exercise', note: 'Keep', rest_seconds: 90 }] };
  const created = await call('/v1/cycles', 'POST', body);
  assert.equal(created.status, 201);
  await engine.exec(`UPDATE user_workout_exercises SET note = 'Changed' WHERE user_program_id = '${body.cycle_id}'`);
  const retried = await call('/v1/cycles', 'POST', body);
  assert.equal(retried.status, 200);
  const { rows } = await engine.query<{ note: string }>(`SELECT note FROM user_workout_exercises WHERE user_program_id = '${body.cycle_id}'`);
  assert.equal(rows[0].note, 'Changed');
});

test('omitted preferences copy only compatible choices from the active cycle', async () => {
  await engine.exec(`INSERT INTO workout_programs (id, name, authoring_key) VALUES (5, 'Shared', 'shared');
    INSERT INTO program_workouts (program_id, workout_id, position) VALUES (5, 1, 1);`);
  const body = { ...cycle, cycle_id: 'ffffffff-ffff-4fff-8fff-ffffffffffff', program_id: 'shared' };
  const response = await call('/v1/cycles', 'POST', body);
  assert.equal(response.status, 201);
  const { rows } = await engine.query<{ note: string }>(`SELECT note FROM user_workout_exercises WHERE user_program_id = '${body.cycle_id}'`);
  assert.equal(rows[0].note, 'Changed');
});

test('invalid preference slots do not create or select a cycle', async () => {
  await engine.exec(`INSERT INTO workout_programs (id, name, authoring_key) VALUES (6, 'Other', 'other');`);
  const body = { ...cycle, cycle_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', program_id: 'other', preferences: [{ workout_exercise_id: 'test-slot', exercise_id: null, note: null, rest_seconds: null }] };
  const response = await call('/v1/cycles', 'POST', body);
  assert.equal(response.status, 400);
  const { rows } = await engine.query<{ active_user_program_id: string }>(`SELECT active_user_program_id FROM users WHERE id = 1`);
  assert.equal(rows[0].active_user_program_id, 'ffffffff-ffff-4fff-8fff-ffffffffffff');
});
