import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { handleCatalogRequest, type CatalogDatabase } from '../src/catalog.ts';
import { validateCatalogSource, type CatalogSource } from '../src/catalog-validation.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const environment = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
  CATALOG_PUBLISH_TOKEN: 'publisher-secret-separate-from-user-tokens',
};

async function userToken(subject = 'catalog-user') {
  return new SignJWT({ sid: 'session_catalog_test' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: 'catalog-test' })
    .setSubject(subject).setIssuer(issuer).setIssuedAt().setNotBefore('0s').setExpirationTime('1m')
    .sign(keys.privateKey);
}

const source = {
  exercises: [{
    key: 'machine_chest_press',
    name: 'Machine Chest Press',
    instructions: 'Use a controlled, comfortable range of motion.',
    stopping_guidance: 'Stop when another full repetition cannot be completed with controlled technique.',
    warmup_guidance: 'Use lighter preparatory sets until ready for the working set.',
    rest_seconds: 180,
    default_reps: { minimum: 6, maximum: 10 },
  }],
  programs: [{
    key: 'machine-full-body',
    name: 'Machine Full Body',
    recommended_weeks: 8,
    format: 'A / B / C',
    emphasis: 'Stable machine work with high effort and simple progression.',
    workouts: [{
      key: 'machine-full-body-a', name: 'Workout A', position: 1,
      exercises: [{ key: 'machine-full-body-a-chest-press', exercise: 'machine_chest_press',
        position: 1, reps: { minimum: 6, maximum: 10 }, scope: 'each_side' }],
    }],
  }, {
    key: 'machine-upper-body',
    name: 'Machine Upper Body',
    recommended_weeks: 8,
    format: 'A / B',
    emphasis: 'A second program sharing the same authored exercise guidance.',
    workouts: [{
      key: 'machine-upper-body-a', name: 'Upper Body A', position: 1,
      exercises: [{ key: 'machine-upper-body-a-chest-press', exercise: 'machine_chest_press',
        position: 1, reps: { minimum: 8, maximum: 12 } }],
    }],
  }],
};

const sourceFingerprint = createHash('sha256').update(JSON.stringify(source)).digest('hex');
const databaseEngine = new PGlite();
const database: CatalogDatabase = {
  query: async (sql, params = []) => (await databaseEngine.query<Record<string, unknown>>(sql, params)).rows,
  transaction: async (sql, params = []) => databaseEngine.transaction(async transaction =>
    (await transaction.query<Record<string, unknown>>(sql, params)).rows),
};

const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await databaseEngine.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await databaseEngine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await databaseEngine.exec(`
  INSERT INTO workout_programs (id, name) VALUES
    (1, 'Full Body'), (2, 'Upper / Lower'), (3, 'Push / Pull / Legs'),
    (4, 'Bro Split'), (5, 'Minimalist Full Body'), (6, 'V-Taper'),
    (7, 'Powerhouse'), (8, 'Classic Physique'),
    (9, 'Free-Weight Full Body'), (10, 'Machine Full Body');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES (1, 'follower', 'kg', 3);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at)
    VALUES ('11111111-1111-4111-8111-111111111111', 1, 10, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  SELECT setval(pg_get_serial_sequence('workout_programs', 'id'), 10);
`);
await databaseEngine.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await databaseEngine.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await databaseEngine.exec(await readFile('../docs/database/migrations/005_cycle_workout_boundaries.sql', 'utf8'));

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

after(async () => { await databaseEngine.close(); });

test('a published program cannot be omitted but an explicit removal marker is valid', () => {
  const original = source.programs[0]!;
  const secondProgram = {
    ...structuredClone(original),
    key: 'second-program',
    name: 'Second Program',
    workouts: original.workouts.map(workout => ({
      ...structuredClone(workout),
      key: 'second-program-a',
      exercises: workout.exercises.map(slot => ({ ...structuredClone(slot), key: 'second-program-a-slot' })),
    })),
  } as CatalogSource['programs'][number];
  const previous = { ...structuredClone(source), programs: [structuredClone(original), secondProgram] } as CatalogSource;
  const omitted = validateCatalogSource({ ...previous, programs: [previous.programs[0]] }, previous);
  assert.ok(omitted.errors.includes('previously published program second-program is missing; mark it removed explicitly'));

  const explicitlyRemoved = validateCatalogSource({
    ...previous,
    programs: [previous.programs[0], { ...secondProgram, removed: true }],
  }, previous);
  assert.deepEqual(explicitlyRemoved.errors, []);
});

test('publisher preview and publish expose the reviewed program to authenticated catalog reads', async () => {
  const userBearer = await userToken('follower');
  const blocked = await handleCatalogRequest(request('/v1/maintenance/catalog/preview', userBearer, 'POST', {
    source, source_fingerprint: sourceFingerprint,
  }), environment, database);
  assert.equal(blocked.status, 403);
  assert.deepEqual(await blocked.json(), { error: { code: 'FORBIDDEN' } });

  const preview = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source, source_fingerprint: sourceFingerprint }), environment, database);
  assert.equal(preview.status, 200);
  const reviewed = await preview.json() as { preview_id: string; backend_fingerprint: string };
  assert.ok(reviewed.preview_id);

  const publishBody = { source, source_fingerprint: sourceFingerprint, ...reviewed };
  const published = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', publishBody), environment, database);
  assert.equal(published.status, 200);
  const acknowledgement = await published.json() as { publication_id: string };
  assert.equal(acknowledgement.publication_id, reviewed.preview_id);

  const catalogResponse = await handleCatalogRequest(request('/v1/catalog', userBearer), environment, database);
  assert.equal(catalogResponse.status, 200);
  const delivered = await catalogResponse.json() as {
    publication_id: string;
    catalog: { programs: Array<{ key: string; name: string; training_days_per_week: number; workouts: Array<{
      key: string; exercises: Array<{ scope: string }>;
    }> }>;
      exercises: Array<{ key: string; stopping_guidance: string }> };
  };
  assert.equal(delivered.publication_id, acknowledgement.publication_id);
  assert.equal(delivered.catalog.programs[0]?.key, 'machine-full-body');
  assert.equal(delivered.catalog.programs[0]?.training_days_per_week,
    delivered.catalog.programs[0]?.workouts.length);
  assert.equal(delivered.catalog.programs[0]?.workouts[0]?.key, 'machine-full-body-a');
  assert.equal(delivered.catalog.programs[0]?.workouts[0]?.exercises[0]?.scope, 'each_side');
  assert.equal(delivered.catalog.exercises[0]?.stopping_guidance, source.exercises[0]?.stopping_guidance);
  assert.deepEqual(delivered.catalog.programs.map(program => program.key), ['machine-full-body', 'machine-upper-body']);

  const repeated = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', publishBody), environment, database);
  assert.equal(repeated.status, 200);
  assert.deepEqual(await repeated.json(), acknowledgement);
  const noChange = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source, source_fingerprint: sourceFingerprint }), environment, database);
  assert.equal(noChange.status, 200);
  assert.deepEqual(await noChange.json().then((body: unknown) => {
    const preview = body as { changes: unknown[]; affected_programs: unknown[] };
    return { changes: preview.changes, affected_programs: preview.affected_programs };
  }), { changes: [], affected_programs: [] });
  const rows = await database.query(`SELECT p.id, p.authoring_key, u.active_user_program_id, r.workout_program_id
    FROM workout_programs p
    JOIN user_programs r ON r.workout_program_id = p.id
    JOIN users u ON u.id = r.user_id
    WHERE p.authoring_key = 'machine-full-body'`);
  assert.deepEqual(rows, [{ id: 10, authoring_key: 'machine-full-body',
    active_user_program_id: '11111111-1111-4111-8111-111111111111', workout_program_id: 10 }]);
});

test('shared guidance edits preview every program and restoring an earlier source preserves training records', async () => {
  const userBearer = await userToken('follower');
  const invalid = structuredClone(source);
  invalid.programs[0]!.workouts[0]!.exercises[0]!.reps.minimum = 0;
  const invalidFingerprint = createHash('sha256').update(JSON.stringify(invalid)).digest('hex');
  const invalidPreview = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source: invalid, source_fingerprint: invalidFingerprint }), environment, database);
  assert.equal(invalidPreview.status, 422);

  const staleReviewResponse = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source, source_fingerprint: sourceFingerprint }), environment, database);
  assert.equal(staleReviewResponse.status, 200);
  const staleReview = await staleReviewResponse.json() as { preview_id: string; backend_fingerprint: string };

  const changed = structuredClone(source);
  changed.exercises[0]!.name = 'Machine Chest Press Revised';
  changed.exercises[0]!.instructions = 'Updated shared instructions for the next publication.';
  changed.exercises[0]!.stopping_guidance = 'Stop at technical failure using the revised movement standard.';
  changed.exercises[0]!.warmup_guidance = 'Use the revised warm-up sequence before the working set.';
  changed.exercises[0]!.rest_seconds = 210;
  changed.exercises[0]!.default_reps = { minimum: 8, maximum: 12 };
  changed.programs[0]!.name = 'Machine Full Body Revised';
  changed.programs[0]!.recommended_weeks = 10;
  changed.programs[0]!.format = 'A / B / C (revised)';
  changed.programs[0]!.emphasis = 'Updated presentation text for the next publication.';
  changed.programs[0]!.workouts[0]!.name = 'Workout A Revised';
  changed.programs[0]!.workouts[0]!.exercises[0]!.reps = { minimum: 8, maximum: 12 };
  const changedFingerprint = createHash('sha256').update(JSON.stringify(changed)).digest('hex');
  const reviewedResponse = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source: changed, source_fingerprint: changedFingerprint }), environment, database);
  assert.equal(reviewedResponse.status, 200);
  const reviewed = await reviewedResponse.json() as {
    preview_id: string; backend_fingerprint: string; affected_programs: string[];
  };
  const impact = reviewed;
  assert.deepEqual(impact.affected_programs, [
    'Machine Full Body Revised (machine-full-body)', 'Machine Upper Body (machine-upper-body)',
  ]);

  const mismatch = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', {
      source: changed, source_fingerprint: sourceFingerprint,
      preview_id: reviewed.preview_id, backend_fingerprint: reviewed.backend_fingerprint,
    }), environment, database);
  assert.equal(mismatch.status, 409);

  const published = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', {
      source: changed, source_fingerprint: changedFingerprint, ...reviewed,
    }), environment, database);
  assert.equal(published.status, 200);

  const stalePublish = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', {
      source, source_fingerprint: sourceFingerprint, ...staleReview,
    }), environment, database);
  assert.equal(stalePublish.status, 409);

  const catalogResponse = await handleCatalogRequest(request('/v1/catalog', userBearer), environment, database);
  const delivered = await catalogResponse.json() as { catalog: {
    programs: Array<{ key: string; name: string; recommended_weeks: number; format: string; emphasis: string;
      workouts: Array<{ name: string; exercises: Array<{ reps: { minimum: number; maximum: number } }> }> }>;
    exercises: Array<{ name: string; instructions: string; stopping_guidance: string; warmup_guidance: string;
      rest_seconds: number; default_reps: { minimum: number; maximum: number } }>;
  } };
  assert.equal(delivered.catalog.exercises[0]?.instructions, changed.exercises[0]?.instructions);
  assert.equal(delivered.catalog.exercises[0]?.name, changed.exercises[0]?.name);
  assert.equal(delivered.catalog.exercises[0]?.stopping_guidance, changed.exercises[0]?.stopping_guidance);
  assert.equal(delivered.catalog.exercises[0]?.warmup_guidance, changed.exercises[0]?.warmup_guidance);
  assert.equal(delivered.catalog.exercises[0]?.rest_seconds, changed.exercises[0]?.rest_seconds);
  assert.deepEqual(delivered.catalog.exercises[0]?.default_reps, changed.exercises[0]?.default_reps);
  assert.equal(delivered.catalog.programs[0]?.name, changed.programs[0]?.name);
  assert.equal(delivered.catalog.programs[0]?.recommended_weeks, changed.programs[0]?.recommended_weeks);
  assert.equal(delivered.catalog.programs[0]?.format, changed.programs[0]?.format);
  assert.equal(delivered.catalog.programs[0]?.emphasis, changed.programs[0]?.emphasis);
  assert.equal(delivered.catalog.programs[0]?.workouts[0]?.name, changed.programs[0]?.workouts[0]?.name);
  assert.deepEqual(delivered.catalog.programs[0]?.workouts[0]?.exercises[0]?.reps,
    changed.programs[0]?.workouts[0]?.exercises[0]?.reps);
  assert.deepEqual(delivered.catalog.programs.map(program => program.key), ['machine-full-body', 'machine-upper-body']);

  await database.query(`INSERT INTO workout_sessions (
      id, user_program_id, workout_id, week_number, workout_name, started_at, completed_at
    ) SELECT '22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111',
      workouts.id, 1, 'Workout A at the time', now(), now()
    FROM workouts WHERE authoring_key = 'machine-full-body-a'`);
  await database.query(`INSERT INTO workout_session_sets (
      workout_session_id, position, workout_exercise_id, exercise_id, prescription, weight, unit, reps, completed_at
    ) SELECT '22222222-2222-4222-8222-222222222222', 1, slots.id, exercises.id,
      '{"name":"Machine Chest Press","instructions":"Captured instructions before correction","reps_min":6,"reps_max":10}'::jsonb,
      40, 'kg', 8, now()
    FROM workout_exercises slots
    JOIN workouts ON workouts.id = slots.workout_id
    JOIN exercises ON exercises.id = slots.exercise_id
    WHERE slots.authoring_key = 'machine-full-body-a-chest-press'`);
  await database.query(`INSERT INTO completed_workouts (user_program_id, week_number, workout_id)
    SELECT '11111111-1111-4111-8111-111111111111', 1, id FROM workouts WHERE authoring_key = 'machine-full-body-a'`);

  const restoreFingerprint = createHash('sha256').update(JSON.stringify(source)).digest('hex');
  const restorePreviewResponse = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source, source_fingerprint: restoreFingerprint }), environment, database);
  assert.equal(restorePreviewResponse.status, 200);
  const restorePreview = await restorePreviewResponse.json() as { preview_id: string; backend_fingerprint: string };
  const restorePublish = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', {
      source, source_fingerprint: restoreFingerprint, ...restorePreview,
    }), environment, database);
  assert.equal(restorePublish.status, 200);

  const restoredCatalogResponse = await handleCatalogRequest(request('/v1/catalog', userBearer), environment, database);
  const restoredCatalog = await restoredCatalogResponse.json() as { catalog: { exercises: Array<{ instructions: string }> } };
  assert.equal(restoredCatalog.catalog.exercises[0]?.instructions, source.exercises[0]?.instructions);
  const preservedTraining = await database.query(`SELECT
      programs.id AS program_id, sets.workout_exercise_id AS slot_id, sets.exercise_id,
      users.preferred_unit, users.training_days,
      sessions.completed_at IS NOT NULL AS session_completed, sessions.workout_name,
      sets.prescription, sets.weight, sets.unit, sets.reps, marks.week_number
    FROM workout_programs programs
    JOIN user_programs cycles ON cycles.workout_program_id = programs.id
    JOIN users ON users.id = cycles.user_id
    JOIN workout_sessions sessions ON sessions.user_program_id = cycles.id
    JOIN workout_session_sets sets ON sets.workout_session_id = sessions.id
    JOIN completed_workouts marks ON marks.user_program_id = cycles.id
    WHERE programs.authoring_key = 'machine-full-body'`);
  assert.deepEqual(preservedTraining, [{
    program_id: 10, slot_id: 1, exercise_id: 1, preferred_unit: 'kg', training_days: 3,
    session_completed: true, workout_name: 'Workout A at the time',
    prescription: { name: 'Machine Chest Press', instructions: 'Captured instructions before correction',
      reps_min: 6, reps_max: 10 },
    weight: '40.000', unit: 'kg', reps: 8, week_number: 1,
  }]);
});

test('failed publication preserves the last complete catalog', async () => {
  const userBearer = await userToken('follower');
  const changed = structuredClone(source);
  changed.programs[0]!.name = 'Machine Full Body (revised)';
  const changedFingerprint = createHash('sha256').update(JSON.stringify(changed)).digest('hex');
  const previewResponse = await handleCatalogRequest(request('/v1/maintenance/catalog/preview',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', { source: changed, source_fingerprint: changedFingerprint }), environment, database);
  assert.equal(previewResponse.status, 200);
  const preview = await previewResponse.json() as { preview_id: string; backend_fingerprint: string };
  const failingDatabase: CatalogDatabase = {
    query: database.query,
    transaction: async () => { throw new Error('simulated database failure'); },
  };
  const response = await handleCatalogRequest(request('/v1/maintenance/catalog/publish',
    environment.CATALOG_PUBLISH_TOKEN, 'POST', {
      source: changed, source_fingerprint: changedFingerprint, ...preview,
    }), environment, failingDatabase);
  assert.equal(response.status, 503);

  const catalogResponse = await handleCatalogRequest(request('/v1/catalog', userBearer), environment, database);
  const delivered = await catalogResponse.json() as { catalog: { programs: Array<{ name: string }> } };
  assert.equal(delivered.catalog.programs[0]?.name, 'Machine Full Body');
});

test('catalog storage outages return a structured unavailable response', async () => {
  const failingDatabase: CatalogDatabase = {
    query: async () => { throw new Error('database connection details'); },
    transaction: database.transaction,
  };
  const response = await handleCatalogRequest(
    request('/v1/catalog', await userToken('follower')),
    environment,
    failingDatabase,
  );
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: { code: 'CATALOG_UNAVAILABLE' } });
});
