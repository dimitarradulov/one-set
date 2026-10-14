import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { handleCatalogRequest, type CatalogDatabase } from '../src/catalog.ts';
import type { CatalogSource } from '../src/catalog-validation.ts';

const issuer = 'https://structure.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const environment = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
  CATALOG_PUBLISH_TOKEN: 'structure-publisher-token',
};
const cycleID = '11111111-1111-4111-8111-111111111111';
const concurrentlyCreatedCycleID = '33333333-3333-4333-8333-333333333333';
const userBearer = await new SignJWT({ sid: 'session_structure_test' })
  .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: 'structure-test' })
  .setSubject('structure-follower').setIssuer(issuer).setIssuedAt().setNotBefore('0s')
  .setExpirationTime('1m').sign(keys.privateKey);

const original = {
  exercises: [
    { key: 'machine_chest_press', name: 'Machine Chest Press',
      instructions: 'Press with control.', stopping_guidance: 'Stop when form breaks.',
      warmup_guidance: 'Warm up progressively.', rest_seconds: 180,
      default_reps: { minimum: 6, maximum: 10 } },
    { key: 'cable_row', name: 'Cable Row',
      instructions: 'Pull with control.', stopping_guidance: 'Stop when form breaks.',
      warmup_guidance: 'Warm up progressively.', rest_seconds: 150,
      default_reps: { minimum: 8, maximum: 12 } },
  ],
  programs: [{ key: 'machine-full-body', name: 'Machine Full Body', recommended_weeks: 8,
    format: 'A / B', emphasis: 'Machine training.', workouts: [
      { key: 'machine-full-body-a', name: 'Workout A', position: 1, exercises: [
        { key: 'machine-full-body-a-chest', exercise: 'machine_chest_press', position: 1,
          reps: { minimum: 6, maximum: 10 } },
      ] },
      { key: 'machine-full-body-b', name: 'Workout B', position: 2, exercises: [
        { key: 'machine-full-body-b-row', exercise: 'cable_row', position: 1,
          reps: { minimum: 8, maximum: 12 } },
      ] },
    ] }, {
    key: 'machine-upper-body', name: 'Machine Upper Body', recommended_weeks: 8,
    format: 'A', emphasis: 'Upper body.', workouts: [
      { key: 'machine-upper-body-a', name: 'Upper Body A', position: 1, exercises: [
        { key: 'machine-upper-body-a-row', exercise: 'cable_row', position: 1,
          reps: { minimum: 8, maximum: 12 } },
      ] },
    ] },
  ],
};

const engine = new PGlite();
const database: CatalogDatabase = {
  query: async (sql, params = []) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
  transaction: async (sql, params = []) => engine.transaction(async transaction =>
    (await transaction.query<Record<string, unknown>>(sql, params)).rows),
};

const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await engine.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await engine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await engine.exec(`
  INSERT INTO workout_programs (id, name) VALUES (10, 'Machine Full Body');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'structure-follower', 'kg', 3);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at)
    VALUES ('${cycleID}', 1, 10, now());
  UPDATE users SET active_user_program_id = '${cycleID}' WHERE id = 1;
  SELECT setval(pg_get_serial_sequence('workout_programs', 'id'), 10);
`);
await engine.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/005_cycle_workout_boundaries.sql', 'utf8'));

function request(path: string, bearer?: string, method = 'GET', body?: unknown): Request {
  return new Request(`https://api.oneset.test${path}`, {
    method,
    headers: {
      ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}),
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

async function publish(source: unknown): Promise<{ changes: Array<{ kind: string; program_key?: string }>;
  affected_programs: string[] }> {
  const sourceFingerprint = createHash('sha256').update(JSON.stringify(source)).digest('hex');
  const previewResponse = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source, source_fingerprint: sourceFingerprint }), environment, database);
  assert.equal(previewResponse.status, 200, JSON.stringify(await previewResponse.clone().json()));
  const preview = await previewResponse.json() as {
    preview_id: string; backend_fingerprint: string;
    changes: Array<{ kind: string; program_key?: string }>;
    affected_programs: string[];
  };
  const response = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', {
      source, source_fingerprint: sourceFingerprint, ...preview,
    }), environment, database);
  assert.equal(response.status, 200);
  return preview;
}

after(async () => { await engine.close(); });

test('structural publication preserves history and applies day changes at the cycle week boundary', async () => {
  await publish(original);
  await database.query(`INSERT INTO user_programs (id, user_id, workout_program_id, started_at)
    VALUES ($1, 1, 10, now())`, [concurrentlyCreatedCycleID]);
  const initializedCycle = await database.query(`SELECT workouts.authoring_key,
      periods.starts_week, periods.ends_week
    FROM user_program_workout_periods periods
    JOIN workouts ON workouts.id = periods.workout_id
    WHERE periods.user_program_id = $1 ORDER BY workouts.authoring_key`, [concurrentlyCreatedCycleID]);
  assert.deepEqual(initializedCycle, [
    { authoring_key: 'machine-full-body-a', starts_week: 1, ends_week: null },
    { authoring_key: 'machine-full-body-b', starts_week: 1, ends_week: null },
  ]);
  const ids = await database.query(`SELECT
      workouts.id AS workout_id, slots.id AS slot_id, exercises.id AS exercise_id
    FROM workouts
    JOIN program_workouts memberships ON memberships.workout_id = workouts.id
    JOIN workout_exercises slots ON slots.workout_id = workouts.id
    JOIN exercises ON exercises.id = slots.exercise_id
    WHERE workouts.authoring_key = 'machine-full-body-a'
      AND slots.authoring_key = 'machine-full-body-a-chest'`);
  const originalIDs = ids[0];
  assert.ok(originalIDs);
  await database.query(`INSERT INTO user_workout_exercises (
      user_program_id, workout_exercise_id, exercise_id, note
    ) VALUES ($1, $2, $3, 'My chest-press setup')`, [cycleID,
      String(originalIDs.slot_id), String(originalIDs.exercise_id)]);
  await database.query(`INSERT INTO workout_sessions (
      id, user_program_id, workout_id, week_number, workout_name, started_at, completed_at
    ) VALUES ('22222222-2222-4222-8222-222222222222', $1, $2, 1, 'Workout A at the time', now(), now())`,
    [cycleID, String(originalIDs.workout_id)]);
  await database.query(`INSERT INTO workout_session_sets (
      workout_session_id, position, workout_exercise_id, exercise_id, prescription,
      weight, unit, reps, completed_at
    ) VALUES ('22222222-2222-4222-8222-222222222222', 1, $1, $2,
      '{"name":"Machine Chest Press","instructions":"Captured before edit","reps_min":6,"reps_max":10}'::jsonb,
      40, 'kg', 8, now())`, [String(originalIDs.slot_id), String(originalIDs.exercise_id)]);
  await database.query(`INSERT INTO completed_workouts (user_program_id, week_number, workout_id)
    VALUES ($1, 1, $2)`, [cycleID, String(originalIDs.workout_id)]);
  await database.query(`UPDATE user_programs SET current_training_week = 3 WHERE id = $1`, [cycleID]);
  await assert.rejects(
    database.query(`UPDATE user_programs SET current_training_week = 2 WHERE id = $1`, [cycleID]),
    /CURRENT_TRAINING_WEEK_REGRESSION/,
  );

  const revised: CatalogSource = structuredClone(original);
  revised.programs[0]!.workouts = [
    { key: 'machine-full-body-c', name: 'Workout C', position: 1, exercises: [
      { key: 'machine-full-body-c-chest', exercise: 'machine_chest_press', position: 1,
        reps: { minimum: 6, maximum: 10 } },
    ] },
    { ...revised.programs[0]!.workouts[0]!, position: 2, exercises: [
      { ...revised.programs[0]!.workouts[0]!.exercises[0]!, removed: true },
      { key: 'machine-full-body-a-row-replacement', exercise: 'cable_row', position: 1,
        reps: { minimum: 8, maximum: 12 } },
    ] },
    { ...revised.programs[0]!.workouts[1]!, position: 3 },
  ];
  const structurePreview = await publish(revised);
  assert.ok(structurePreview.changes.some(change =>
    change.kind === 'update' && change.program_key === 'machine-full-body'));
  assert.ok(structurePreview.affected_programs.includes('Machine Full Body (machine-full-body)'));

  const currentResponse = await handleCatalogRequest(request('/v1/catalog', userBearer), environment, database);
  assert.equal(currentResponse.status, 200);
  const current = await currentResponse.json() as { catalog: { programs: Array<{
    key: string; training_days_per_week: number; workouts: Array<{
      key: string; exercises: Array<{ key: string }>;
    }>;
  }> } };
  const program = current.catalog.programs.find(candidate => candidate.key === 'machine-full-body');
  assert.ok(program);
  assert.equal(program.training_days_per_week, 3);
  assert.deepEqual(program.workouts.map(workout => workout.key), [
    'machine-full-body-c', 'machine-full-body-a', 'machine-full-body-b',
  ]);
  assert.deepEqual(program.workouts[1]?.exercises.map(slot => slot.key), [
    'machine-full-body-a-row-replacement',
  ]);

  const boundaryState = await database.query(`SELECT cycles.current_training_week,
      periods.workout_id, workouts.authoring_key, periods.starts_week, periods.ends_week
    FROM user_programs cycles
    JOIN user_program_workout_periods periods ON periods.user_program_id = cycles.id
    JOIN workouts ON workouts.id = periods.workout_id
    WHERE cycles.id = $1 ORDER BY workouts.authoring_key, periods.starts_week`, [cycleID]);
  assert.equal(boundaryState.find(row => row.authoring_key === 'machine-full-body-c')?.starts_week, 3);
  assert.equal(boundaryState.find(row => row.authoring_key === 'machine-full-body-a')?.starts_week, 1);
  assert.equal(boundaryState.find(row => row.authoring_key === 'machine-full-body-a')?.ends_week, null);
  assert.equal(boundaryState[0]?.current_training_week, 3);

  const slotState = await database.query(`SELECT slots.authoring_key, preferences.note
    FROM user_workout_exercises preferences
    JOIN workout_exercises slots ON slots.id = preferences.workout_exercise_id
    WHERE preferences.user_program_id = $1`, [cycleID]);
  assert.deepEqual(slotState, [{ authoring_key: 'machine-full-body-a-chest', note: 'My chest-press setup' }]);
  const history = await database.query(`SELECT sessions.workout_name, sets.exercise_id, sets.prescription,
      marks.week_number, cycles.current_training_week
    FROM workout_sessions sessions
    JOIN workout_session_sets sets ON sets.workout_session_id = sessions.id
    JOIN completed_workouts marks ON marks.user_program_id = sessions.user_program_id
    JOIN user_programs cycles ON cycles.id = sessions.user_program_id
    WHERE sessions.id = '22222222-2222-4222-8222-222222222222'`);
  assert.deepEqual(history, [{ workout_name: 'Workout A at the time',
    exercise_id: originalIDs.exercise_id,
    prescription: { name: 'Machine Chest Press', instructions: 'Captured before edit', reps_min: 6, reps_max: 10 },
    week_number: 1, current_training_week: 3,
  }]);
  const required = await database.query(`SELECT workouts.authoring_key, required.workout_position
    FROM required_workouts_for_cycle_week($1, 3) required
    JOIN workouts ON workouts.id = required.workout_id
    ORDER BY required.workout_position`, [cycleID]);
  assert.deepEqual(required.map(row => row.authoring_key), [
    'machine-full-body-c', 'machine-full-body-a', 'machine-full-body-b',
  ]);

  const removal = structuredClone(revised);
  removal.programs[0]!.workouts = [
    { ...removal.programs[0]!.workouts[0]!, position: 1 },
    { ...removal.programs[0]!.workouts[2]!, position: 2, exercises: [
      { ...removal.programs[0]!.workouts[2]!.exercises[0]!, removed: true },
    ] },
    { ...removal.programs[0]!.workouts[1]!, removed: true },
  ];
  const removalPreview = await publish(removal);
  assert.ok(removalPreview.changes.some(change =>
    change.kind === 'update' && change.program_key === 'machine-full-body'));

  const afterRemoval = await database.query(`SELECT workouts.authoring_key,
      periods.starts_week, periods.ends_week
    FROM user_program_workout_periods periods
    JOIN workouts ON workouts.id = periods.workout_id
    WHERE periods.user_program_id = $1 ORDER BY workouts.authoring_key`, [cycleID]);
  assert.equal(afterRemoval.find(row => row.authoring_key === 'machine-full-body-a')?.ends_week, 2);
  assert.equal(afterRemoval.find(row => row.authoring_key === 'machine-full-body-c')?.starts_week, 3);
  const currentRequired = await database.query(`SELECT workouts.authoring_key, required.workout_position
    FROM required_workouts_for_cycle_week($1, 3) required
    JOIN workouts ON workouts.id = required.workout_id
    ORDER BY required.workout_position`, [cycleID]);
  assert.deepEqual(currentRequired.map(row => row.authoring_key), [
    'machine-full-body-c', 'machine-full-body-b',
  ]);
  const earlierRequired = await database.query(`SELECT workout_id
    FROM required_workouts_for_cycle_week($1, 2)`, [cycleID]);
  assert.deepEqual(earlierRequired, []);
  const afterRemovalResponse = await handleCatalogRequest(request('/v1/catalog', userBearer), environment, database);
  const afterRemovalBody = await afterRemovalResponse.json() as { catalog: { programs: Array<{
    key: string; training_days_per_week: number; workouts: Array<{ key: string; exercises: unknown[] }>;
  }> } };
  const visibleProgram = afterRemovalBody.catalog.programs.find(candidate => candidate.key === 'machine-full-body');
  assert.ok(visibleProgram);
  assert.equal(visibleProgram.training_days_per_week, 2);
  assert.deepEqual(visibleProgram.workouts.map(workout => workout.key), [
    'machine-full-body-c', 'machine-full-body-b',
  ]);
  assert.deepEqual(visibleProgram.workouts[1]?.exercises, []);

  // Restoring and removing again within the same current week must not leave
  // overlapping active periods or duplicate active rows for the same day.
  await publish(revised);
  const afterRestore = await database.query(`SELECT starts_week, ends_week
    FROM user_program_workout_periods
    WHERE user_program_id = $1 AND workout_id = $2 ORDER BY starts_week`,
    [cycleID, String(boundaryState.find(row => row.authoring_key === 'machine-full-body-a')?.workout_id)]);
  assert.deepEqual(afterRestore, [
    { starts_week: 1, ends_week: 2 },
    { starts_week: 3, ends_week: null },
  ]);
  const repeatedRemoval = structuredClone(removal);
  repeatedRemoval.programs[0]!.emphasis = 'Machine training. Refreshed after restoring Workout A.';
  await publish(repeatedRemoval);
  const afterSameWeekRemoval = await database.query(`SELECT starts_week, ends_week
    FROM user_program_workout_periods
    WHERE user_program_id = $1 AND workout_id = $2 ORDER BY starts_week`,
    [cycleID, String(boundaryState.find(row => row.authoring_key === 'machine-full-body-a')?.workout_id)]);
  assert.deepEqual(afterSameWeekRemoval, [{ starts_week: 1, ends_week: 2 }]);
  const noActiveSameWeekRows = await database.query(`SELECT workout_id
    FROM user_program_workout_periods
    WHERE user_program_id = $1 AND ends_week IS NULL`, [cycleID]);
  const currentWorkoutIDs = await database.query(`SELECT workout_id
    FROM program_workouts WHERE program_id = 10 AND position IS NOT NULL`);
  assert.equal(noActiveSameWeekRows.length, currentWorkoutIDs.length);
});
