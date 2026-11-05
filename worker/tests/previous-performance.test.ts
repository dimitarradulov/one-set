import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { readFile } from 'node:fs/promises';
import { handlePreviousPerformanceRequest, type PreviousPerformanceDatabase } from '../src/previous-performance.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
};
async function token(subject = 'result_user', claims = {}) {
  return new SignJWT({ sid: `sess_${subject}`, ...claims })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setSubject(subject).setIssuer(issuer)
    .setIssuedAt().setNotBefore('0s').setExpirationTime('1m').sign(keys.privateKey);
}
function request(bearer?: string) {
  return new Request('https://api.oneset.test/v1/me/previous-performance', {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}
const engine = new PGlite();
const database: PreviousPerformanceDatabase = {
  query: async (sql, params) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
};
const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await engine.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await engine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await engine.exec(`INSERT INTO workout_programs (id, name) VALUES (10, 'Program A'), (11, 'Program B');`);
await engine.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/011_catalog_repository_sync.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await engine.exec(`
  INSERT INTO workouts (id, name, authoring_key) VALUES
    (100, 'Day A', 'day-a'), (101, 'Day B', 'day-b');
  INSERT INTO program_workouts (program_id, workout_id, position) VALUES (10, 100, 1), (10, 101, 2);
  INSERT INTO exercises (id, name, instructions, reps_min, reps_max, rest_seconds,
    warmup_guidance, authoring_key) VALUES
    (100, 'Row', 'Row', 8, 12, 120, '{"steps":[],"note":""}', 'row'),
    (101, 'Row Variation', 'Row', 8, 12, 120, '{"steps":[],"note":""}', 'row-variation');
  INSERT INTO workout_exercises (id, workout_id, exercise_id, position, reps_min, reps_max,
    authoring_key) VALUES (100, 100, 100, 1, 8, 12, 'slot-a'),
      (101, 101, 100, 1, 8, 12, 'slot-b'), (102, 100, 101, 2, 8, 12, 'slot-c'),
      (103, 100, 100, 3, 8, 12, 'slot-a-repeat');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'result_user', 'kg', 2), (2, 'other_user', 'lb', 2);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 10, now());
  INSERT INTO workout_sessions (id, user_program_id, workout_id, week_number, workout_name,
    started_at, completed_at) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 100,
      2, 'Captured Day A', '2026-01-01T10:00:00Z', '2026-01-01T10:30:00Z'),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111111', 101,
      3, 'Captured Day B', '2026-02-01T10:00:00Z', '2026-02-01T10:30:00Z'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '22222222-2222-4222-8222-222222222222', 100,
      4, 'Foreign Day A', '2026-03-01T10:00:00Z', '2026-03-01T10:30:00Z');
  INSERT INTO workout_session_sets (workout_session_id, position, workout_exercise_id,
    exercise_id, prescription, weight, unit, reps, completed_at) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 1, 100, 100, '{"name":"Old captured row"}',
      0, 'kg', 8, '2026-01-01T10:10:00Z'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 2, 103, 100, '{"name":"Captured repeated row"}',
      88, 'lb', 9, '2026-01-01T10:11:00Z'),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 1, 101, 100, '{"name":"Captured row"}',
      75.5, 'lb', 10, '2026-02-01T10:10:00Z'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 1, 100, 100, '{"name":"Foreign row"}',
      500, 'lb', 15, '2026-03-01T10:10:00Z');
`);

after(async () => { await engine.close(); });

test('returns same-workout history alongside the latest fallback, scoped to the verified account', async () => {
  const response = await handlePreviousPerformanceRequest(request(await token()), env, database);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  const body = await response.json() as { results: Record<string, unknown>[] };
  const rowResults = body.results.filter(result => result.exercise_key === 'row');
  assert.equal(rowResults.length, 3);
  assert.deepEqual(rowResults.map(result => [result.workout_key, result.slot_key]), [
    ['day-b', 'slot-b'], ['day-a', 'slot-a-repeat'], ['day-a', 'slot-a'],
  ]);
  assert.equal(rowResults[0]?.weight, '75.500');
  assert.equal(rowResults[0]?.unit, 'lb');
  assert.equal(rowResults[0]?.workout_name, 'Captured Day B');
  assert.equal(rowResults[2]?.weight, '0.000');
  assert.equal(rowResults[2]?.unit, 'kg');
  assert.equal(rowResults[2]?.workout_name, 'Captured Day A');
  assert.equal(body.results.some(result => result.exercise_key === 'row-variation'), false);
  assert.equal(body.results.some(result => result.workout_name === 'Foreign Day A'), false);
});

test('unauthenticated or foreign-token claims cannot read results', async () => {
  const unauthenticated = await handlePreviousPerformanceRequest(request(), env, {
    query: async () => { assert.fail('unauthenticated requests must not query result data'); },
  });
  assert.equal(unauthenticated.status, 401);
  const invalidParty = await handlePreviousPerformanceRequest(
    request(await token('result_user', { azp: 'https://untrusted.test' })), env, database,
  );
  assert.equal(invalidParty.status, 401);
});
