import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { readFile } from 'node:fs/promises';
import { handleCompletedSessionRequest, type SessionDatabase } from '../src/sessions.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
};
async function token(subject = 'session_user') {
  return new SignJWT({ sid: `session-${subject}` })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setSubject(subject)
    .setIssuer(issuer).setIssuedAt().setNotBefore('0s').setExpirationTime('1m')
    .sign(keys.privateKey);
}
const engine = new PGlite();
const database: SessionDatabase = {
  query: async (sql, params) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
};
const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await engine.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await engine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await engine.exec(`INSERT INTO workout_programs (id, name) VALUES (10, 'Machine Full Body');`);
await engine.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await engine.exec(`
  INSERT INTO workouts (id, name, authoring_key) VALUES
    (100, 'Workout A', 'day-a'), (101, 'Workout B', 'day-b');
  INSERT INTO program_workouts (program_id, workout_id, position) VALUES
    (10, 100, 1), (10, 101, 2);
  INSERT INTO exercises (id, name, instructions, reps_min, reps_max, rest_seconds,
      warmup_guidance, authoring_key) VALUES
    (100, 'Row', 'Current row instructions', 8, 12, 120, '{"steps":[],"note":"Current warmup"}', 'row-a'),
    (101, 'Press', 'Current press instructions', 8, 12, 150, '{"steps":[],"note":"Current warmup"}', 'press-b'),
    (102, 'Row B', 'Current row instructions', 8, 12, 120, '{"steps":[],"note":"Current warmup"}', 'row-c');
  INSERT INTO workout_exercises (id, workout_id, exercise_id, position, reps_min, reps_max,
      authoring_key, rep_scope) VALUES
    (100, 100, 100, 1, 8, 12, 'slot-a', 'reps'),
    (101, 100, 101, 2, 8, 12, 'slot-b', 'reps'),
    (102, 101, 102, 1, 8, 12, 'slot-c', 'reps');
  SELECT setval(pg_get_serial_sequence('workout_programs', 'id'), 10);
  SELECT setval(pg_get_serial_sequence('workouts', 'id'), 101);
  SELECT setval(pg_get_serial_sequence('exercises', 'id'), 102);
  SELECT setval(pg_get_serial_sequence('workout_exercises', 'id'), 102);
`);
await engine.exec(await readFile('../docs/database/migrations/005_cycle_workout_boundaries.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/006_completed_session_write.sql', 'utf8'));
await engine.exec(`
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'session_user', 'kg', 2), (2, 'other_user', 'lb', 2);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 10, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  UPDATE users SET active_user_program_id = '22222222-2222-4222-8222-222222222222' WHERE id = 2;
  SELECT setval(pg_get_serial_sequence('users', 'id'), 2);
`);

after(async () => { await engine.close(); });

function sessionBody(overrides: Record<string, unknown> = {}) {
  return {
    session_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    cycle_id: '11111111-1111-4111-8111-111111111111',
    program_key: 'machine-full-body',
    workout_key: 'day-a',
    week_number: 1,
    workout_name: 'Captured Day A',
    started_at: '2026-10-01T10:00:00.000Z',
    completed_at: '2026-10-01T10:45:00.000Z',
    note: 'Felt strong',
    sets: [
      {
        workout_exercise_key: 'slot-a', exercise_key: 'row-a', position: 1,
        prescription: {
          name: 'Captured Row', instructions: 'Old captured row guidance',
          stopping_guidance: 'Stop if form breaks.',
          warmup_guidance: { steps: [], note: 'Captured warmup guidance' },
          video_key: null, reps_min: 8, reps_max: 12, rep_scope: 'each_side', rest_seconds: 135,
        },
        weight: 72.5, unit: 'lb', reps: 10, completed_at: '2026-10-01T10:12:00.000Z',
      },
      {
        workout_exercise_key: 'slot-b', exercise_key: 'press-b', position: 2,
        prescription: {
          name: 'Captured Press', instructions: 'Old captured press guidance',
          stopping_guidance: 'Stop if form breaks.',
          warmup_guidance: { steps: [], note: 'Captured press warmup' },
          video_key: 'private/press.mp4', reps_min: 8, reps_max: 12, rep_scope: 'reps', rest_seconds: 150,
        },
        weight: null, unit: 'lb', reps: null, completed_at: null,
      },
    ],
    ...overrides,
  };
}

function request(bearer: string | undefined, body: unknown, path = '/v1/sessions/completed') {
  return new Request(`https://api.oneset.test${path}`, {
    method: 'POST',
    headers: {
      ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

test('completed session writes captured partial results and completion mark atomically', async () => {
  const response = await handleCompletedSessionRequest(request(await token(), sessionBody()), env, database);
  assert.equal(response.status, 201, JSON.stringify(await response.clone().json()));
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
  assert.deepEqual(await response.json(), {
    session_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', result: 'created',
  });
  const stored = await database.query(`SELECT session.workout_name, session.note,
      result.position, result.exercise_id, result.prescription, result.weight::text AS weight,
      result.unit, result.reps, result.completed_at IS NOT NULL AS performed
    FROM workout_sessions AS session
    JOIN workout_session_sets AS result ON result.workout_session_id = session.id
    WHERE session.id = $1 ORDER BY result.position`, ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']);
  assert.equal(stored.length, 2);
  assert.equal(stored[0]?.workout_name, 'Captured Day A');
  assert.equal(stored[0]?.note, 'Felt strong');
  assert.equal(stored[0]?.weight, '72.500');
  assert.equal(stored[0]?.unit, 'lb');
  assert.equal(stored[0]?.reps, 10);
  assert.equal(stored[0]?.performed, true);
  assert.equal((stored[0]?.prescription as { instructions: string }).instructions, 'Old captured row guidance');
  assert.equal(stored[1]?.weight, null);
  assert.equal(stored[1]?.reps, null);
  assert.equal(stored[1]?.performed, false);
  const mark = await database.query(`SELECT workout_id FROM completed_workouts
    WHERE user_program_id = $1 AND week_number = 1`, ['11111111-1111-4111-8111-111111111111']);
  assert.deepEqual(mark, [{ workout_id: 100 }]);
  const progress = await database.query(`SELECT current_training_week FROM user_programs
    WHERE id = $1`, ['11111111-1111-4111-8111-111111111111']);
  assert.deepEqual(progress, [{ current_training_week: 1 }]);
});

test('equal concurrent retries acknowledge one session and never advance progress twice', async () => {
  const body = sessionBody();
  const retries = await Promise.all(Array.from({ length: 4 }, () =>
    handleCompletedSessionRequest(request(awaitToken, body), env, database)));
  for (const response of retries) {
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      session_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', result: 'acknowledged',
    });
  }
  const counts = await database.query(`SELECT
      (SELECT count(*)::integer FROM workout_sessions WHERE id = $1) AS sessions,
      (SELECT count(*)::integer FROM workout_session_sets WHERE workout_session_id = $1) AS sets,
      (SELECT count(*)::integer FROM completed_workouts WHERE user_program_id = $2 AND week_number = 1) AS marks`,
  ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111']);
  assert.deepEqual(counts, [{ sessions: 1, sets: 2, marks: 1 }]);
});

const awaitToken = await token();

test('different content for an existing identity conflicts without overwriting stored results', async () => {
  const response = await handleCompletedSessionRequest(request(awaitToken,
    sessionBody({ note: 'Different content' })), env, database);
  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: { code: 'SESSION_CONFLICT' } });
  const stored = await database.query(`SELECT note FROM workout_sessions
    WHERE id = $1`, ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']);
  assert.deepEqual(stored, [{ note: 'Felt strong' }]);
});

test('completion of all required days advances the monotonic cycle week', async () => {
  const body = sessionBody({
    session_id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    workout_key: 'day-b', workout_name: 'Workout B',
    sets: [{
      workout_exercise_key: 'slot-c', exercise_key: 'row-c', position: 1,
      prescription: {
        name: 'Captured Row B', instructions: 'Guidance', stopping_guidance: 'Stop safely.',
        warmup_guidance: { steps: [], note: 'Warmup' }, video_key: null,
        reps_min: 8, reps_max: 12, rep_scope: 'reps', rest_seconds: 120,
      },
      weight: 0, unit: 'kg', reps: 8, completed_at: '2026-10-01T10:12:00.000Z',
    }],
  });
  const response = await handleCompletedSessionRequest(request(awaitToken, body), env, database);
  assert.equal(response.status, 201, JSON.stringify(await response.clone().json()));
  const progress = await database.query(`SELECT current_training_week FROM user_programs
    WHERE id = $1`, ['11111111-1111-4111-8111-111111111111']);
  assert.deepEqual(progress, [{ current_training_week: 2 }]);
  const retried = await handleCompletedSessionRequest(request(awaitToken, sessionBody()), env, database);
  assert.equal(retried.status, 200);
  assert.deepEqual(await retried.json(), {
    session_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', result: 'acknowledged',
  });
  const afterRetry = await database.query(`SELECT current_training_week FROM user_programs
    WHERE id = $1`, ['11111111-1111-4111-8111-111111111111']);
  assert.deepEqual(afterRetry, [{ current_training_week: 2 }]);
});

test('invalid session values, empty work, and another owner’s cycle are rejected', async () => {
  const noCompletedSets = sessionBody({
    session_id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    sets: sessionBody().sets.map(set => ({ ...set, weight: null, reps: null, completed_at: null })),
  });
  const empty = await handleCompletedSessionRequest(request(awaitToken, noCompletedSets), env, database);
  assert.equal(empty.status, 400);

  const badWeight = sessionBody({
    session_id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    sets: sessionBody().sets.map((set, index) => index === 0 ? { ...set, weight: 1.2345 } : set),
  });
  const invalid = await handleCompletedSessionRequest(request(awaitToken, badWeight), env, database);
  assert.equal(invalid.status, 400);

  const badTimestamp = sessionBody({
    session_id: 'abababab-abab-4bab-8bab-abababababab',
    started_at: 'yesterday',
  });
  const invalidTimestamp = await handleCompletedSessionRequest(request(awaitToken, badTimestamp), env, database);
  assert.equal(invalidTimestamp.status, 400);

  const otherCycle = sessionBody({
    session_id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    cycle_id: '22222222-2222-4222-8222-222222222222',
  });
  const forbidden = await handleCompletedSessionRequest(request(awaitToken, otherCycle), env, database);
  assert.equal(forbidden.status, 403);
  const noRows = await database.query(`SELECT count(*)::integer AS count FROM workout_sessions
    WHERE id = $1`, ['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee']);
  assert.deepEqual(noRows, [{ count: 0 }]);
});

test('a failed completion mark rolls back session and captured slots together', async () => {
  const before = await database.query(`SELECT current_training_week FROM user_programs
    WHERE id = $1`, ['11111111-1111-4111-8111-111111111111']);
  await engine.exec(`CREATE FUNCTION fail_completion_mark() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RAISE EXCEPTION 'injected completion failure'; END; $$;
    CREATE TRIGGER fail_completion_mark BEFORE INSERT ON completed_workouts
    FOR EACH ROW EXECUTE FUNCTION fail_completion_mark();`);
  const body = sessionBody({ session_id: 'ffffffff-ffff-4fff-8fff-ffffffffffff' });
  const response = await handleCompletedSessionRequest(request(awaitToken, body), env, database);
  assert.equal(response.status, 503);
  const counts = await database.query(`SELECT
      (SELECT count(*)::integer FROM workout_sessions WHERE id = $1) AS sessions,
      (SELECT count(*)::integer FROM workout_session_sets WHERE workout_session_id = $1) AS sets,
      (SELECT current_training_week FROM user_programs WHERE id = $2) AS week`,
  ['ffffffff-ffff-4fff-8fff-ffffffffffff', '11111111-1111-4111-8111-111111111111']);
  assert.deepEqual(counts, [{ sessions: 0, sets: 0,
    week: before[0]?.current_training_week }]);
  await engine.exec('DROP TRIGGER fail_completion_mark ON completed_workouts; DROP FUNCTION fail_completion_mark();');
});

test('missing or invalid authentication never reaches the database', async () => {
  for (const bearer of [undefined, 'invalid']) {
    const response = await handleCompletedSessionRequest(request(bearer, sessionBody()), env, {
      query: async () => { assert.fail('invalid requests must not query the database'); },
    });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: { code: 'AUTH_REQUIRED' } });
  }
});

test('nullable fields require explicit null and accept null values', async () => {
  const body = sessionBody({
    session_id: '12121212-1212-4212-8212-121212121212',
    note: null,
    sets: sessionBody().sets.map(set => ({
      ...set,
      prescription: { ...set.prescription, video_key: null, rest_seconds: null },
    })),
  });
  const response = await handleCompletedSessionRequest(request(awaitToken, body), env, database);
  assert.equal(response.status, 201, JSON.stringify(await response.clone().json()));
  const saved = await database.query(`SELECT session.note IS NULL AS note_is_null,
      result.prescription ? 'video_key' AS has_video_key,
      result.prescription->'video_key' = 'null'::jsonb AS video_is_null,
      result.prescription ? 'rest_seconds' AS has_rest_seconds,
      result.prescription->'rest_seconds' = 'null'::jsonb AS rest_is_null
    FROM workout_sessions AS session
    JOIN workout_session_sets AS result ON result.workout_session_id = session.id
    WHERE session.id = $1 ORDER BY result.position`, [body.session_id]);
  assert.deepEqual(saved, [
    { note_is_null: true, has_video_key: true, video_is_null: true, has_rest_seconds: true, rest_is_null: true },
    { note_is_null: true, has_video_key: true, video_is_null: true, has_rest_seconds: true, rest_is_null: true },
  ]);

  const noDatabase: SessionDatabase = { query: async () => { throw new Error('omitted null fields must not reach SQL'); } };
  const omittedNote = JSON.parse(JSON.stringify(sessionBody({
    session_id: '13131313-1313-4313-8313-131313131313', note: null,
  }))) as Record<string, unknown>;
  delete omittedNote.note;
  const missingNote = await handleCompletedSessionRequest(request(awaitToken, omittedNote), env, noDatabase);
  assert.equal(missingNote.status, 400);

  const omittedVideo = JSON.parse(JSON.stringify(sessionBody({
    session_id: '14141414-1414-4414-8414-141414141414',
  }))) as { sets: Array<{ prescription: Record<string, unknown> }> };
  delete omittedVideo.sets[0]!.prescription.video_key;
  const missingVideo = await handleCompletedSessionRequest(request(awaitToken, omittedVideo), env, noDatabase);
  assert.equal(missingVideo.status, 400);

  const omittedRest = JSON.parse(JSON.stringify(sessionBody({
    session_id: '15151515-1515-4515-8515-151515151515',
  }))) as { sets: Array<{ prescription: Record<string, unknown> }> };
  delete omittedRest.sets[0]!.prescription.rest_seconds;
  const missingRest = await handleCompletedSessionRequest(request(awaitToken, omittedRest), env, noDatabase);
  assert.equal(missingRest.status, 400);
});

test('PostgreSQL int4 boundaries are enforced for session values', async () => {
  const maxInt = 2_147_483_647;
  const base = sessionBody();
  const maxValues = sessionBody({
    session_id: '16161616-1616-4616-8616-161616161616',
    week_number: maxInt,
    sets: base.sets.map((set, index) => index === 0 ? {
      ...set,
      reps: maxInt,
      prescription: { ...set.prescription, reps_min: maxInt, reps_max: maxInt },
    } : set),
  });
  const maximum = await handleCompletedSessionRequest(request(awaitToken, maxValues), env, database);
  assert.equal(maximum.status, 201, JSON.stringify(await maximum.clone().json()));

  const noDatabase: SessionDatabase = { query: async () => { throw new Error('overflow must not reach SQL'); } };
  const tooLarge = [
    sessionBody({ session_id: '17171717-1717-4717-8717-171717171717', week_number: maxInt + 1 }),
    sessionBody({ session_id: '18181818-1818-4818-8818-181818181818', sets: base.sets.map((set, index) => index === 0 ? { ...set, position: maxInt + 1 } : set) }),
    sessionBody({ session_id: '19191919-1919-4919-8919-191919191919', sets: base.sets.map((set, index) => index === 0 ? { ...set, prescription: { ...set.prescription, reps_min: maxInt + 1, reps_max: maxInt + 1 } } : set) }),
    sessionBody({ session_id: '20202020-2020-4020-8020-202020202020', sets: base.sets.map((set, index) => index === 0 ? { ...set, prescription: { ...set.prescription, reps_max: maxInt + 1 } } : set) }),
    sessionBody({ session_id: '21212121-2121-4121-8121-212121212121', sets: base.sets.map((set, index) => index === 0 ? { ...set, reps: maxInt + 1 } : set) }),
  ];
  for (const body of tooLarge) {
    const response = await handleCompletedSessionRequest(request(awaitToken, body), env, noDatabase);
    assert.equal(response.status, 400, JSON.stringify(await response.clone().json()));
  }
});

test('captured slot positions must match array order without gaps', async () => {
  const noDatabase: SessionDatabase = { query: async () => { throw new Error('invalid order must not reach SQL'); } };
  const base = sessionBody().sets;
  for (const positions of [[2, 1], [1, 3]]) {
    const body = sessionBody({
      session_id: positions[0] === 2
        ? '22222221-2222-4222-8222-222222222221'
        : '23232323-2323-4323-8323-232323232323',
      sets: base.map((set, index) => ({ ...set, position: positions[index] })),
    });
    const response = await handleCompletedSessionRequest(request(awaitToken, body), env, noDatabase);
    assert.equal(response.status, 400);
  }
});
