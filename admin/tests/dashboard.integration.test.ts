import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { access } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import net from 'node:net';
import { PGlite } from '@electric-sql/pglite';
import { exportJWK, exportSPKI, generateKeyPair, SignJWT, type JWTVerifyGetKey } from 'jose';
import { chromium } from 'playwright-core';
import { parse } from 'yaml';
import { handleDashboardAction, loadDashboard, renderDashboard, type DashboardEnvironment, type DashboardResult, type ExerciseFields, type ProgramFields } from '../src/dashboard.ts';
import { handleCatalogRequest, type CatalogDatabase, type CatalogConfiguration } from '../../worker/src/catalog.ts';
import { synchronizePublication } from '../src/repository-sync.ts';
import { catalogSourceFiles } from '../../worker/src/catalog-generation.ts';
import { verifyCloudflareAccess } from '../../worker/src/cloudflare-access.ts';
import type { CatalogSource } from '../../worker/src/catalog-validation.ts';
import { loadPublicationHistory, prepareHistoricalRestoration, publishHistoricalRestoration, reconcileHistoricalSource,
  type HistoryActionResult } from '../src/history.ts';

const founder = 'founder@example.test';
const team = 'https://oneset-test.cloudflareaccess.com';
const audience = 'dashboard-request-test';
const publisherToken = 'test-publisher-token';
const accessKeys = await generateKeyPair('RS256', { extractable: true });
const accessKeySource: JWTVerifyGetKey = async () => accessKeys.publicKey;
const accessJWK = { ...(await exportJWK(accessKeys.publicKey)), kid: 'dashboard-request-test', alg: 'RS256', use: 'sig' };
const clerkKeys = await generateKeyPair('RS256', { extractable: true });
const apiEnvironment: CatalogConfiguration = {
  CLERK_ISSUER: 'https://clerk.integration.test',
  CLERK_JWT_KEY: await exportSPKI(clerkKeys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://app.integration.test',
  CATALOG_PUBLISH_TOKEN: publisherToken,
  ACCESS_TEAM_DOMAIN: team,
  ACCESS_AUDIENCE: audience,
  ACCESS_APPROVED_EMAIL: founder,
};
const environment: DashboardEnvironment = {
  ACCESS_TEAM_DOMAIN: team,
  ACCESS_AUDIENCE: audience,
  ACCESS_APPROVED_EMAIL: founder,
  CATALOG_ENVIRONMENT: 'development',
  CATALOG_API_BASE_URL: '',
  CATALOG_PUBLISH_TOKEN: publisherToken,
};
let transactionFailure = false;
let server: ReturnType<typeof createServer> | undefined;
let apiOrigin = '';
const engine = new PGlite();
const exercisesDoc = parse(await readFile(new URL('../../worker/catalog/exercises.yaml', import.meta.url), 'utf8')) as { exercises: CatalogSource['exercises'] };
const programFiles = (await readdir(new URL('../../worker/catalog/programs/', import.meta.url)))
  .filter(name => name.endsWith('.yaml')).sort();
const source: CatalogSource = {
  exercises: exercisesDoc.exercises,
  programs: await Promise.all(programFiles.map(async name => parse(await readFile(
    join(new URL('../../worker/catalog/programs/', import.meta.url).pathname, name), 'utf8')) as CatalogSource['programs'][number])),
};
for (const exercise of source.exercises) {
  exercise.video_key = `integration/${exercise.key}.mp4`;
  exercise.future_editor_metadata = { retained_for: exercise.key };
}
source.release_note = 'Metadata from a future authoring tool';
source.programs[0]!.editor_hint = { preserve: true };
source.programs[0]!.removed = true;
source.programs[0]!.workouts[0]!.removed = true;
source.programs[0]!.workouts[0]!.exercises[0]!.removed = true;
source.programs[0]!.workouts.slice(1).forEach((workout, index) => { workout.position = index + 1; });
source.programs[0]!.workouts[0]!.exercises.slice(1).forEach((slot, index) => { slot.position = index + 1; });

const initialSchema = await readFile(new URL('../../docs/database/migrations/001_documented_schema.sql', import.meta.url), 'utf8');
await engine.exec(`BEGIN;\n${initialSchema.slice(initialSchema.indexOf('CREATE TYPE'))}`);
await engine.exec(await readFile(new URL('../../docs/database/migrations/002_completed_setup.sql', import.meta.url), 'utf8'));
await engine.exec(await readFile(new URL('../../docs/database/migrations/003_catalog_publication.sql', import.meta.url), 'utf8'));
await engine.exec(await readFile(new URL('../../docs/database/migrations/011_catalog_repository_sync.sql', import.meta.url), 'utf8'));
const fingerprint = 'b'.repeat(64);
await engine.query(`INSERT INTO public.catalog_publications (id, source_fingerprint, backend_fingerprint, source_document)
  VALUES ($1, $2, 'empty', $3::jsonb)`, ['publication-request-test', fingerprint, JSON.stringify(source)]);
await engine.query(`UPDATE public.catalog_state SET publication_id = $1, source_fingerprint = $2, source_document = $3::jsonb
  WHERE singleton = true`, ['publication-request-test', fingerprint, JSON.stringify(source)]);
const database: CatalogDatabase = {
  query: async (sql, params = []) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
  transaction: async (sql, params = []) => {
    if (transactionFailure) throw new Error('simulated transaction failure');
    return engine.transaction(async transaction => (await transaction.query<Record<string, unknown>>(sql, params)).rows);
  },
};

async function token(email = founder, issuer = team): Promise<string> {
  return new SignJWT({ email })
    .setProtectedHeader({ alg: 'RS256', kid: 'dashboard-request-test' })
    .setIssuer(issuer).setAudience(audience).setIssuedAt().setExpirationTime('2m').sign(accessKeys.privateKey);
}

async function clerkToken(): Promise<string> {
  return new SignJWT({ sid: 'session-integration', azp: 'https://app.integration.test', sts: 'active' })
    .setProtectedHeader({ alg: 'RS256' }).setIssuer(apiEnvironment.CLERK_ISSUER)
    .setSubject('user_integration').setIssuedAt().setExpirationTime('2m').sign(clerkKeys.privateKey);
}

function form(fields: Partial<ProgramFields> & Record<string, string> = {}): FormData {
  const values: Record<string, string> = {
    program_key: source.programs[1]!.key,
    name: 'Upper / Lower Updated',
    format: '4 workouts · Upper / Lower',
    emphasis: 'Balanced strength with a tested emphasis.',
    recommended_weeks: '14',
    ...fields,
  };
  const result = new FormData();
  for (const [key, value] of Object.entries(values)) result.set(key, value);
  return result;
}

function exerciseForm(fields: Partial<ExerciseFields> & Record<string, string> = {}, catalogSource: CatalogSource = source,
  publicationFingerprint = fingerprint): FormData {
  const selected = catalogSource.exercises[0]!;
  const values: Record<string, string> = {
    exercise_key: selected.key,
    is_new: 'false',
    name: `${selected.name} revised`,
    instructions: 'Use the revised full controlled range of motion.',
    stopping_guidance: 'Stop when another controlled repetition is not possible.',
    warmup_guidance: 'Prepare with gradually heavier warmup sets.',
    rest_seconds: String(selected.rest_seconds + 15),
    default_reps_minimum: String(selected.default_reps.minimum + 1),
    default_reps_maximum: String(selected.default_reps.maximum + 1),
    catalog_source: JSON.stringify(catalogSource),
    publication_fingerprint: publicationFingerprint,
    ...fields,
  };
  const result = new FormData();
  for (const [key, value] of Object.entries(values)) result.set(key, value);
  return result;
}

function cloneForm(input: FormData): FormData {
  const result = new FormData();
  for (const [key, value] of input.entries()) result.set(key, String(value));
  return result;
}

async function publishExerciseFields(review: Extract<DashboardResult, { view: 'review'; contentKind: 'exercise' }>,
  fields: FormData): Promise<FormData> {
  const result = new FormData();
  for (const [key, value] of fields.entries()) result.set(key, String(value));
  result.set('catalog_source', JSON.stringify(review.candidateSource));
  result.set('source_fingerprint', review.reviewSourceFingerprint);
  result.set('preview_id', review.previewID);
  result.set('backend_fingerprint', review.backendFingerprint);
  return result;
}

function publicationForm(fields: Record<string, string>): FormData {
  const result = new FormData();
  for (const [key, value] of Object.entries(fields)) result.set(key, value);
  return result;
}

async function dashboardRequest(action: string, fields: FormData, accessToken?: string, origin = 'https://dashboard.test', submittedOrigin = origin) {
  const body = new URLSearchParams();
  for (const [key, value] of fields.entries()) body.append(key, String(value));
  return new Request(`${origin}/?_action=${action}`, {
    method: 'POST',
    headers: {
      Origin: submittedOrigin,
      'Sec-Fetch-Site': 'same-origin',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cf-Access-Jwt-Assertion': accessToken ?? await token(),
    },
    body,
  });
}

async function publishFields(review: Extract<DashboardResult, { view: 'review'; contentKind: 'program' }>): Promise<FormData> {
  const published = { ...review.source, programs: review.source.programs.map(program => program.key === review.fields.program_key ? {
    ...program, name: review.fields.name, format: review.fields.format, emphasis: review.fields.emphasis,
    recommended_weeks: Number(review.fields.recommended_weeks),
  } : program) };
  const { createHash } = await import('node:crypto');
  const sourceFingerprint = createHash('sha256').update(JSON.stringify(published)).digest('hex');
  return form({ ...review.fields, publication_fingerprint: review.sourceFingerprint,
    source_fingerprint: sourceFingerprint, preview_id: review.previewID, backend_fingerprint: review.backendFingerprint });
}

async function readCurrentSource(): Promise<SourceResponse> {
  const rows = await database.query(`SELECT publication_id, source_fingerprint, source_document FROM public.catalog_state WHERE singleton = true`);
  const row = rows[0]!;
  return { publication_id: String(row.publication_id), source_fingerprint: String(row.source_fingerprint), source: row.source_document as CatalogSource };
}


async function readAppCatalog(): Promise<CatalogSource> {
  const response = await handleCatalogRequest(new Request(`${apiOrigin}/v1/catalog`, {
    headers: { Authorization: `Bearer ${await clerkToken()}` },
  }), apiEnvironment, database, accessKeySource);
  assert.equal(response.status, 200);
  return (await response.json() as { catalog: CatalogSource }).catalog;
}


function restorationForm(review: Extract<HistoryActionResult, { view: 'history-review' }>): FormData {
  return publicationForm({
    publication_id: review.publication.publication_id,
    publication_fingerprint: review.current.source_fingerprint,
    catalog_source: JSON.stringify(review.candidate),
    source_fingerprint: review.sourceFingerprint,
    backend_fingerprint: review.backendFingerprint,
    preview_id: review.previewID,
  });
}

async function createOlderSnapshot(): Promise<CatalogSource> {
  const old = structuredClone(source);
  old.programs = old.programs.slice(0, -1);
  const first = old.programs[0]!;
  delete first.removed;
  for (const [index, workout] of first.workouts.entries()) {
    delete workout.removed;
    workout.position = index + 1;
    for (const [slotIndex, slot] of workout.exercises.entries()) {
      delete slot.removed;
      slot.position = slotIndex + 1;
    }
  }
  const revisedProgram = old.programs[1]!;
  revisedProgram.name = 'Upper / Lower Historical Name';
  const currentProgram = source.programs.find(program => program.key === revisedProgram.key)!;
  const laterWorkout = [...currentProgram.workouts].reverse().find(workout => workout.removed !== true)!;
  revisedProgram.workouts = revisedProgram.workouts.filter(workout => workout.key !== laterWorkout.key);
  revisedProgram.workouts.filter(workout => workout.removed !== true).forEach((workout, index) => { workout.position = index + 1; });
  const oldWorkout = revisedProgram.workouts.find(workout => workout.removed !== true)!;
  const currentWorkout = currentProgram.workouts.find(workout => workout.key === oldWorkout.key)!;
  const laterSlot = [...currentWorkout.exercises].reverse().find(slot => slot.removed !== true)!;
  oldWorkout.exercises = oldWorkout.exercises.filter(slot => slot.key !== laterSlot.key);
  oldWorkout.exercises.filter(slot => slot.removed !== true).forEach((slot, index) => { slot.position = index + 1; });

  const laterProgram = source.programs.at(-1)!;
  const laterExerciseKeys = new Set(laterProgram.workouts.flatMap(workout => workout.exercises.map(slot => slot.exercise)));
  const oldReferences = new Set(old.programs.flatMap(program => program.workouts.flatMap(workout => workout.exercises.map(slot => slot.exercise))));
  const laterExercise = [...laterExerciseKeys].find(key => !oldReferences.has(key));
  if (laterExercise) old.exercises = old.exercises.filter(exercise => exercise.key !== laterExercise);
  assert.deepEqual((await import('../../worker/src/catalog-validation.ts')).validateCatalogSource(old).errors, []);
  return old;
}

async function insertTrainingFixture(): Promise<void> {
  const selectedProgram = source.programs.find(program => program.key === 'upper-lower')!;
  const selectedWorkout = selectedProgram.workouts.find(workout => workout.removed !== true)!;
  const selectedSlot = selectedWorkout.exercises.find(slot => slot.removed !== true)!;
  const [user] = (await engine.query<{ id: number }>(`INSERT INTO public.users
    (clerk_user_id, preferred_unit, training_days) VALUES ('history-user', 'kg', 3) RETURNING id`)).rows;
  assert.ok(user);
  const enrollmentID = '00000000-0000-4000-8000-000000000065';
  const [program] = (await engine.query<{ id: number }>(`SELECT id FROM public.workout_programs WHERE authoring_key = $1`, [selectedProgram.key])).rows;
  const [workout] = (await engine.query<{ id: number }>(`SELECT id FROM public.workouts WHERE authoring_key = $1`, [selectedWorkout.key])).rows;
  const [exercise] = (await engine.query<{ id: number }>(`SELECT id FROM public.exercises WHERE authoring_key = $1`, [selectedSlot.exercise])).rows;
  const [slot] = (await engine.query<{ id: number }>(`SELECT id FROM public.workout_exercises WHERE authoring_key = $1`, [selectedSlot.key])).rows;
  assert.ok(program && workout && exercise && slot);
  await engine.query(`INSERT INTO public.user_programs (id, user_id, workout_program_id, started_at) VALUES ($1, $2, $3, '2026-01-01T00:00:00Z')`, [enrollmentID, String(user.id), String(program.id)]);
  await engine.query(`UPDATE public.users SET active_user_program_id = $1 WHERE id = $2`, [enrollmentID, String(user.id)]);
  await engine.query(`INSERT INTO public.user_workout_exercises (user_program_id, workout_exercise_id, exercise_id, note, rest_seconds)
    VALUES ($1, $2, $3, 'remembered replacement context', 120)`, [enrollmentID, String(slot.id), String(exercise.id)]);
  const sessionID = '00000000-0000-4000-8000-000000000066';
  await engine.query(`INSERT INTO public.workout_sessions (id, user_program_id, workout_id, week_number, workout_name, started_at, completed_at, note)
    VALUES ($1, $2, $3, 2, 'Captured session name', '2026-01-02T00:00:00Z', '2026-01-02T00:40:00Z', 'captured note')`, [sessionID, enrollmentID, String(workout.id)]);
  await engine.query(`INSERT INTO public.workout_session_sets
    (workout_session_id, position, workout_exercise_id, exercise_id, prescription, note, weight, unit, reps, completed_at)
    VALUES ($1, 1, $2, $3, $4::jsonb, 'captured set', 22.5, 'kg', 9, '2026-01-02T00:30:00Z')`,
  [sessionID, String(slot.id), String(exercise.id), JSON.stringify({ exercise: selectedSlot.exercise, reps: selectedSlot.reps, instructions: 'captured prescription' })]);
  await engine.query(`INSERT INTO public.completed_workouts (user_program_id, week_number, workout_id) VALUES ($1, 2, $2)`, [enrollmentID, String(workout.id)]);
}

async function trainingSnapshot(): Promise<unknown> {
  return (await engine.query(`SELECT
    (SELECT jsonb_agg(to_jsonb(row) ORDER BY row.id) FROM public.users row) AS users,
    (SELECT jsonb_agg(to_jsonb(row) ORDER BY row.id) FROM public.user_programs row) AS enrollments,
    (SELECT jsonb_agg(to_jsonb(row) ORDER BY row.user_program_id, row.workout_exercise_id) FROM public.user_workout_exercises row) AS preferences,
    (SELECT jsonb_agg(to_jsonb(row) ORDER BY row.id) FROM public.workout_sessions row) AS sessions,
    (SELECT jsonb_agg(to_jsonb(row) ORDER BY row.workout_session_id, row.position) FROM public.workout_session_sets row) AS sets,
    (SELECT jsonb_agg(to_jsonb(row) ORDER BY row.user_program_id, row.week_number, row.workout_id) FROM public.completed_workouts row) AS completions`)).rows[0];
}

interface SourceResponse { source: CatalogSource; publication_id: string; source_fingerprint: string }

server = createServer(async (incoming, outgoing) => {
  try {
    const chunks: Buffer[] = [];
    for await (const chunk of incoming) chunks.push(Buffer.from(chunk));
    const body = Buffer.concat(chunks);
    const request = new Request(`${apiOrigin}${incoming.url ?? '/'}`, {
      method: incoming.method,
      headers: new Headers(incoming.headers as HeadersInit),
      ...(body.length ? { body } : {}),
    });
    if (new URL(request.url).pathname === '/cdn-cgi/access/certs') {
      outgoing.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=60' });
      outgoing.end(JSON.stringify({ keys: [accessJWK] }));
      return;
    }
    const response = await handleCatalogRequest(request, apiEnvironment, database, accessKeySource);
    outgoing.writeHead(response.status, Object.fromEntries(response.headers.entries()));
    outgoing.end(await response.text());
  } catch {
    outgoing.writeHead(500);
    outgoing.end();
  }
});
server.listen(0, '127.0.0.1');
await once(server, 'listening');
const address = server.address();
assert.ok(address && typeof address === 'object');
apiOrigin = `http://127.0.0.1:${address.port}`;
environment.CATALOG_API_BASE_URL = apiOrigin;

after(async () => {
  if (server?.listening) { server.close(); await once(server, 'close'); }
  await engine.close();
});

test('protected edit → review → edit → publish → app catalog keeps unknown metadata, removed identities, and state', async () => {
  const accessToken = await token();
  const get = new Request('https://dashboard.test/', { headers: { 'Cf-Access-Jwt-Assertion': accessToken } });
  const loaded = await loadDashboard(get, environment, { keySource: accessKeySource });
  assert.equal(loaded.source?.source.programs.length, 10);
  assert.ok(loaded.source?.source.programs[0]?.removed);
  const initialHTML = renderDashboard(undefined, loaded.source, environment);
  assert.match(initialHTML, /action="@editProgram"/);
  assert.match(initialHTML, /Edit details/);
  assert.match(initialHTML, /Removed/);
  assert.match(initialHTML, /Browse workout templates and shared exercises/);
  assert.match(initialHTML, /Weighted Chin-Up/);
  assert.doesNotMatch(initialHTML, /localStorage|autosave|test-publisher-token/i);

  const selected = source.programs[1]!;
  const invalid = form({ program_key: selected.key, name: '   ', publication_fingerprint: loaded.source!.source_fingerprint });
  const invalidResult = await handleDashboardAction('review', await dashboardRequest('reviewProgram', invalid, accessToken), invalid,
    environment, { keySource: accessKeySource });
  assert.equal(invalidResult.view, 'edit');
  if (invalidResult.view === 'edit') assert.equal(invalidResult.errors?.name, 'Enter a program name.');

  const edited = form({ program_key: selected.key, publication_fingerprint: loaded.source!.source_fingerprint });
  const editResult = await handleDashboardAction('edit', await dashboardRequest('editProgram', edited, accessToken), edited,
    environment, { keySource: accessKeySource });
  assert.equal(editResult.view, 'edit');
  if (editResult.view === 'edit') assert.equal(editResult.fields.name, 'Upper / Lower Updated');

  const reviewForm = form({ program_key: selected.key, publication_fingerprint: loaded.source!.source_fingerprint });
  const reviewResult = await handleDashboardAction('review', await dashboardRequest('reviewProgram', reviewForm, accessToken), reviewForm,
    environment, { keySource: accessKeySource });
  assert.equal(reviewResult.view, 'review');
  if (reviewResult.view !== 'review' || reviewResult.contentKind !== 'program') return;
  assert.ok(reviewResult.changes.length > 0);
  assert.ok(reviewResult.affectedPrograms.some(item => item.includes(selected.key)));
  assert.equal((await readCurrentSource()).source.programs[1]!.name, selected.name, 'review must not mutate published source');

  const returnedToEdit = await handleDashboardAction('edit', await dashboardRequest('editProgram', reviewForm, accessToken), reviewForm,
    environment, { keySource: accessKeySource });
  assert.equal(returnedToEdit.view, 'edit');
  if (returnedToEdit.view === 'edit' && returnedToEdit.contentKind === 'program') assert.equal(returnedToEdit.fields.emphasis, 'Balanced strength with a tested emphasis.');

  const exactReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', reviewForm, accessToken), reviewForm,
    environment, { keySource: accessKeySource });
  assert.equal(exactReview.view, 'review');
  if (exactReview.view !== 'review' || exactReview.contentKind !== 'program') return;
  const submitted = await publishFields(exactReview);
  const published = await handleDashboardAction('publish', await dashboardRequest('publishProgram', submitted, accessToken), submitted,
    environment, { keySource: accessKeySource });
  assert.equal(published.view, 'success');
  const current = await readCurrentSource();
  assert.equal(current.source.programs[1]!.name, 'Upper / Lower Updated');
  assert.equal(current.source.programs[1]!.format, '4 workouts · Upper / Lower');
  assert.deepEqual(current.source.programs[0]!.editor_hint, { preserve: true });
  assert.equal(current.source.release_note, 'Metadata from a future authoring tool');
  assert.equal(current.source.programs[0]!.removed, true);
  assert.equal(current.source.programs[0]!.workouts[0]!.removed, true);
  assert.equal(current.source.programs[0]!.workouts[0]!.exercises[0]!.removed, true);

  const appCatalog = await handleCatalogRequest(new Request(`${apiOrigin}/v1/catalog`, {
    headers: { Authorization: `Bearer ${await clerkToken()}` },
  }), apiEnvironment, database, accessKeySource);
  assert.equal(appCatalog.status, 200);
  const catalog = await appCatalog.json() as { catalog: CatalogSource };
  assert.equal(catalog.catalog.programs.find(program => program.key === selected.key)?.name, 'Upper / Lower Updated');
  assert.equal(catalog.catalog.programs.find(program => program.key === source.programs[0]!.key)?.removed, true,
    'removed program identity remains available to current followers with its unavailable marker');
});

test('historical correction keeps later identities, rejects stale review, retries safely, and preserves training data', async () => {
  await insertTrainingFixture();
  const oldSource = await createOlderSnapshot();
  const { createHash } = await import('node:crypto');
  const oldFingerprint = createHash('sha256').update(JSON.stringify(oldSource)).digest('hex');
  await engine.query(`INSERT INTO public.catalog_publications (id, source_fingerprint, backend_fingerprint, source_document, published_at)
    VALUES ('publication-history-old', $1, 'empty', $2::jsonb, '2026-01-01T00:00:00Z')`, [oldFingerprint, JSON.stringify(oldSource)]);

  const accessToken = await token();
  const currentBefore = await readCurrentSource();
  assert.equal(currentBefore.source.exercises[0]?.video_key, `integration/${currentBefore.source.exercises[0]?.key}.mp4`, 'current source still has future exercise metadata before correction');
  const historyResponse = await handleCatalogRequest(new Request(`${apiOrigin}/v1/maintenance/catalog/publications`, {
    headers: { 'Cf-Access-Jwt-Assertion': accessToken },
  }), apiEnvironment, database, accessKeySource);
  assert.equal(historyResponse.status, 200);
  const listed = await historyResponse.json() as { publications: Array<{ publication_id: string }> };
  assert.ok(listed.publications.some(publication => publication.publication_id === 'publication-history-old'));
  const historyUnauthorized = await handleCatalogRequest(new Request(`${apiOrigin}/v1/maintenance/catalog/publications/publication-history-old`),
    apiEnvironment, database, accessKeySource);
  assert.equal(historyUnauthorized.status, 401);
  assert.equal((await readCurrentSource()).source_fingerprint, currentBefore.source_fingerprint,
    'history inspection reads must not change the published catalog');
  const candidateResult = reconcileHistoricalSource(oldSource, currentBefore.source);
  assert.equal(candidateResult.source.exercises[0]?.video_key, `integration/${candidateResult.source.exercises[0]?.key}.mp4`, 'reconciled source retains future exercise metadata');
  assert.equal(candidateResult.retained.programs, 1);
  assert.ok(candidateResult.retained.workouts >= 1);
  assert.ok(candidateResult.retained.slots >= 1);
  assert.ok(candidateResult.retained.exercises >= 1);
  const laterProgramKey = currentBefore.source.programs.at(-1)!.key;
  const laterWorkoutKey = currentBefore.source.programs.find(program => program.key === source.programs[1]!.key)!.workouts.at(-1)!.key;
  const laterSlotKey = currentBefore.source.programs.find(program => program.key === source.programs[1]!.key)!.workouts[0]!.exercises.at(-1)!.key;
  assert.ok(candidateResult.source.programs.some(program => program.key === laterProgramKey));
  assert.ok(candidateResult.source.programs.find(program => program.key === source.programs[1]!.key)?.workouts.some(workout => workout.key === laterWorkoutKey));
  assert.ok(candidateResult.source.programs.find(program => program.key === source.programs[1]!.key)?.workouts.some(workout => workout.exercises.some(slot => slot.key === laterSlotKey)));

  const trainingBefore = await trainingSnapshot();
  const select = publicationForm({ publication_id: 'publication-history-old' });
  const firstReview = await prepareHistoricalRestoration(await dashboardRequest('restorePublication', select, accessToken), select,
    environment, { keySource: accessKeySource });
  assert.equal(firstReview.view, 'history-review');
  if (firstReview.view !== 'history-review') return;
  assert.ok(firstReview.changes.some(change => change.kind.includes('restore')) || firstReview.changes.some(change => change.kind === 'update program'));

  const competingSource = await readCurrentSource();
  const competitorFields = form({ program_key: competingSource.source.programs[2]!.key,
    name: 'Intervening publication', publication_fingerprint: competingSource.source_fingerprint });
  const competitorReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', competitorFields, accessToken), competitorFields,
    environment, { keySource: accessKeySource });
  assert.equal(competitorReview.view, 'review');
  if (competitorReview.view !== 'review' || competitorReview.contentKind !== 'program') return;
  const competitorPublish = await handleDashboardAction('publish', await dashboardRequest('publishProgram', await publishFields(competitorReview), accessToken),
    await publishFields(competitorReview), environment, { keySource: accessKeySource });
  assert.equal(competitorPublish.view, 'success');

  const staleForm = restorationForm(firstReview);
  const stale = await publishHistoricalRestoration(await dashboardRequest('publishRestoration', staleForm, accessToken), staleForm,
    environment, { keySource: accessKeySource });
  assert.equal(stale.view, 'history-error');
  if (stale.view === 'history-error') assert.equal(stale.status, 409);

  const latestSelection = await prepareHistoricalRestoration(await dashboardRequest('restorePublication', select, accessToken), select,
    environment, { keySource: accessKeySource });
  assert.equal(latestSelection.view, 'history-review');
  if (latestSelection.view !== 'history-review') return;
  const retryForm = restorationForm(latestSelection);
  const uncertain = await publishHistoricalRestoration(await dashboardRequest('publishRestoration', retryForm, accessToken), retryForm,
    environment, { keySource: accessKeySource, fetcher: async (input, init) => {
      const response = await fetch(input, init);
      if (new URL(String(input)).pathname.endsWith('/publish')) throw new Error('simulated lost response after commit');
      return response;
    } });
  assert.equal(uncertain.view, 'history-error');
  if (uncertain.view === 'history-error') assert.ok(uncertain.retry, 'an uncertain same-visit failure retains an exact retry form');
  const countAfterCommit = await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  const retry = await publishHistoricalRestoration(await dashboardRequest('publishRestoration', retryForm, accessToken), retryForm,
    environment, { keySource: accessKeySource, repositorySync: async publicationID => ({
      status: 'failed', publicationID, detail: 'simulated repository outage',
    }) });
  assert.equal(retry.view, 'history-success');
  if (retry.view === 'history-success') {
    assert.equal(retry.repositoryStatus, 'failed', 'a committed correction reports repository failure separately');
    assert.match(retry.repositoryDetail ?? '', /simulated repository outage/);
    const syncFields = publicationForm({ publication_id: retry.publicationID });
    const synced = await handleDashboardAction('sync', await dashboardRequest('syncCatalog', syncFields, accessToken), syncFields,
      environment, { keySource: accessKeySource, repositorySync: async publicationID => ({
        status: 'synchronized', publicationID, commitSHA: 'history-sync-commit',
      }) });
    assert.equal(synced.view, 'success');
    if (synced.view === 'success') {
      assert.equal(synced.publicationID, retry.publicationID, 'sync retry targets the already-published historical correction');
      assert.equal(synced.repositoryStatus, 'synchronized');
    }
  }
  const countAfterRetry = await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  assert.equal(countAfterRetry.rows[0]?.count, countAfterCommit.rows[0]?.count, 'retry must reuse the uncertain publication');

  const appResponse = await handleCatalogRequest(new Request(`${apiOrigin}/v1/catalog`, {
    headers: { Authorization: `Bearer ${await clerkToken()}` },
  }), apiEnvironment, database, accessKeySource);
  assert.equal(appResponse.status, 200);
  const app = await appResponse.json() as { catalog: CatalogSource };
  const correctedProgram = app.catalog.programs.find(program => program.key === oldSource.programs[1]!.key);
  assert.equal(correctedProgram?.name, 'Upper / Lower Historical Name');
  assert.ok(app.catalog.programs.some(program => program.key === laterProgramKey));
  assert.ok(correctedProgram?.workouts.some(workout => workout.key === laterWorkoutKey));
  assert.ok(correctedProgram?.workouts.some(workout => workout.exercises.some(slot => slot.key === laterSlotKey)));
  assert.deepEqual(await trainingSnapshot(), trainingBefore, 'catalog correction must leave user, enrollment, preferences, sessions, sets, and completion marks unchanged');
  const correctedSource = await readCurrentSource();
  assert.equal(correctedSource.source.exercises[0]?.video_key, `integration/${correctedSource.source.exercises[0]?.key}.mp4`, 'historical correction retains unknown exercise metadata');

  const browserSource = structuredClone(oldSource);
  browserSource.programs[1]!.name = 'Upper / Lower Browser Historical';
  const browserFingerprint = createHash('sha256').update(JSON.stringify(browserSource)).digest('hex');
  await engine.query(`INSERT INTO public.catalog_publications (id, source_fingerprint, backend_fingerprint, source_document, published_at)
    VALUES ('publication-history-browser', $1, 'empty', $2::jsonb, '2026-01-02T00:00:00Z')`, [browserFingerprint, JSON.stringify(browserSource)]);
});

test('shared exercise edit and creation publish through the complete-source review while preserving slot prescriptions', async () => {
  const accessToken = await token();
  const baseline = await readCurrentSource();
  assert.equal(baseline.source.exercises[0]?.video_key, `integration/${baseline.source.exercises[0]?.key}.mp4`, `fixture metadata survives the preceding history and publication workflows: ${JSON.stringify(baseline.source.exercises.slice(0, 3).map(exercise => [exercise.key, exercise.video_key]))}`);
  const usage = (catalog: CatalogSource, exerciseKey: string) => catalog.programs.flatMap(program =>
    program.removed === true ? [] : program.workouts.flatMap(workout => workout.removed === true ? [] :
      workout.exercises.filter(slot => slot.removed !== true && slot.exercise === exerciseKey).map(slot => ({ program, workout, slot }))));
  const selected = baseline.source.exercises.find(exercise => new Set(usage(baseline.source, exercise.key).map(row => row.program.key)).size > 1);
  assert.ok(selected, 'fixture contains a shared exercise used by multiple programs');
  const selectedUses = usage(baseline.source, selected.key);
  const originalSlots = baseline.source.programs.map(program => ({ key: program.key, workouts: program.workouts.map(workout => ({
    key: workout.key, exercises: workout.exercises.map(slot => ({ key: slot.key, exercise: slot.exercise, reps: slot.reps, scope: slot.scope })),
  })) }));

  const invalid = exerciseForm({ exercise_key: selected.key, name: selected.name, instructions: '   ' }, baseline.source, baseline.source_fingerprint);
  const invalidResult = await handleDashboardAction('review-exercise', await dashboardRequest('reviewExercise', invalid, accessToken), invalid,
    environment, { keySource: accessKeySource });
  assert.equal(invalidResult.view, 'edit');
  if (invalidResult.view === 'edit' && invalidResult.contentKind === 'exercise') {
    assert.equal(invalidResult.errors?.instructions, 'Enter technique instructions.');
  }

  const editedFields = exerciseForm({ exercise_key: selected.key, name: 'Shared Movement Updated',
    instructions: 'Use the updated controlled range.', stopping_guidance: 'Stop at a technical limit.',
    warmup_guidance: 'Use progressive warmup sets.', rest_seconds: '210', default_reps_minimum: '7', default_reps_maximum: '11' },
  baseline.source, baseline.source_fingerprint);
  const reviewResult = await handleDashboardAction('review-exercise', await dashboardRequest('reviewExercise', editedFields, accessToken), editedFields,
    environment, { keySource: accessKeySource });
  assert.equal(reviewResult.view, 'review');
  if (reviewResult.view !== 'review' || reviewResult.contentKind !== 'exercise') return;
  for (const programKey of new Set(selectedUses.map(row => row.program.key))) {
    assert.ok(reviewResult.affectedPrograms.some(item => item.includes(programKey)), `review identifies affected program ${programKey}`);
  }
  const reviewHTML = renderDashboard(reviewResult, undefined, environment);
  assert.match(reviewHTML, /Review shared exercise changes/);
  for (const programKey of new Set(selectedUses.map(row => row.program.key))) assert.match(reviewHTML, new RegExp(programKey));
  assert.equal(JSON.stringify((await readCurrentSource()).source), JSON.stringify(baseline.source), 'review leaves the published source unchanged');

  const publishForm = await publishExerciseFields(reviewResult, editedFields);
  const publicationCountBefore = await database.query(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  const uncertain = await handleDashboardAction('publish-exercise', await dashboardRequest('publishExercise', publishForm, accessToken), publishForm,
    environment, { keySource: accessKeySource, fetcher: async (input, init) => {
      const response = await fetch(input, init);
      if (new URL(String(input)).pathname.endsWith('/publish')) throw new Error('simulated lost response after shared exercise commit');
      return response;
    } });
  assert.equal(uncertain.view, 'error', 'the dashboard reports an interrupted publication response');
  const published = await handleDashboardAction('publish-exercise', await dashboardRequest('publishExercise', publishForm, accessToken), publishForm,
    environment, { keySource: accessKeySource });
  assert.equal(published.view, 'success');
  const publicationCountAfterRetry = await database.query(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  assert.equal(Number(publicationCountAfterRetry[0]?.count), Number(publicationCountBefore[0]?.count) + 1,
    'the exercise retry reuses the reviewed publication identity');
  const afterEdit = await readCurrentSource();
  const updated = afterEdit.source.exercises.find(exercise => exercise.key === selected.key)!;
  assert.equal(updated.name, 'Shared Movement Updated');
  assert.equal(updated.instructions, 'Use the updated controlled range.');
  assert.equal(updated.rest_seconds, 210);
  assert.deepEqual(updated.default_reps, { minimum: 7, maximum: 11 });
  assert.equal(updated.video_key, `integration/${selected.key}.mp4`);
  assert.deepEqual(updated.future_editor_metadata, { retained_for: selected.key },
    'shared exercise edits retain media identifiers and metadata added by other authoring versions');
  assert.deepEqual(afterEdit.source.programs.map(program => ({ key: program.key, workouts: program.workouts.map(workout => ({
    key: workout.key, exercises: workout.exercises.map(slot => ({ key: slot.key, exercise: slot.exercise, reps: slot.reps, scope: slot.scope })),
  })) })), originalSlots, 'shared guidance changes leave slot rep bounds and unilateral scope unchanged');

  const newBaseline = await readCurrentSource();
  const addedFields = exerciseForm({ exercise_key: 'integration-distinct-movement', is_new: 'true', name: 'Integration Distinct Movement',
    instructions: 'Move through a controlled range.', stopping_guidance: 'Stop before control is lost.',
    warmup_guidance: 'Use lighter warmup sets first.', rest_seconds: '120', default_reps_minimum: '8', default_reps_maximum: '12' },
  newBaseline.source, newBaseline.source_fingerprint);
  const invalidNew = cloneForm(addedFields);
  invalidNew.set('warmup_guidance', '');
  const invalidNewResult = await handleDashboardAction('review-exercise', await dashboardRequest('reviewExercise', invalidNew, accessToken), invalidNew,
    environment, { keySource: accessKeySource });
  assert.equal(invalidNewResult.view, 'edit');
  if (invalidNewResult.view === 'edit' && invalidNewResult.contentKind === 'exercise') {
    assert.equal(invalidNewResult.errors?.warmup_guidance, 'Enter warmup guidance.');
  }
  const conflict = cloneForm(addedFields);
  conflict.set('exercise_key', selected.key);
  const conflictResult = await handleDashboardAction('review-exercise', await dashboardRequest('reviewExercise', conflict, accessToken), conflict,
    environment, { keySource: accessKeySource });
  assert.equal(conflictResult.view, 'edit');
  if (conflictResult.view === 'edit' && conflictResult.contentKind === 'exercise') {
    assert.match(conflictResult.errors?.exercise_key ?? '', /already used/);
  }

  const addedReview = await handleDashboardAction('review-exercise', await dashboardRequest('reviewExercise', addedFields, accessToken), addedFields,
    environment, { keySource: accessKeySource });
  assert.equal(addedReview.view, 'review');
  if (addedReview.view !== 'review' || addedReview.contentKind !== 'exercise') return;
  const addedPublishForm = await publishExerciseFields(addedReview, addedFields);
  const addedPublished = await handleDashboardAction('publish-exercise', await dashboardRequest('publishExercise', addedPublishForm, accessToken), addedPublishForm,
    environment, { keySource: accessKeySource });
  assert.equal(addedPublished.view, 'success');
  assert.equal((await readCurrentSource()).source.exercises.find(exercise => exercise.key === 'integration-distinct-movement')?.name,
    'Integration Distinct Movement');
});


test('direct, cross-origin, and wrong-identity actions cannot reach the publisher', async () => {
  const fields = form({ publication_fingerprint: (await readCurrentSource()).source_fingerprint });
  const noToken = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, ''), fields,
    environment, { keySource: accessKeySource });
  assert.equal(noToken.view, 'error');
  if (noToken.view === 'error') assert.equal(noToken.status, 401);
  const wrongOrigin = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, await token(), 'https://dashboard.test', 'https://attacker.test'), fields,
    environment, { keySource: accessKeySource });
  assert.equal(wrongOrigin.view, 'error');
  if (wrongOrigin.view === 'error') assert.equal(wrongOrigin.status, 401);
  const wrongIdentity = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, await token('intruder@example.test')), fields,
    environment, { keySource: accessKeySource });
  assert.equal(wrongIdentity.view, 'error');
  if (wrongIdentity.view === 'error') assert.equal(wrongIdentity.status, 401);
  const syncFields = new FormData();
  syncFields.set('publication_id', (await readCurrentSource()).publication_id);
  const rejectedSync = await handleDashboardAction('sync', await dashboardRequest('syncCatalog', syncFields, ''), syncFields,
    environment, { keySource: accessKeySource });
  assert.equal(rejectedSync.view, 'error');
  if (rejectedSync.view === 'error') assert.equal(rejectedSync.status, 401);
});

test('history page and direct correction actions enforce server authorization and same-origin checks', async () => {
  const list = await loadPublicationHistory(new Request('https://dashboard.test/history'), environment, { keySource: accessKeySource });
  assert.equal(list.error?.status, 401);
  const selection = publicationForm({ publication_id: 'publication-history-old' });
  const missing = await prepareHistoricalRestoration(await dashboardRequest('restorePublication', selection, ''), selection,
    environment, { keySource: accessKeySource });
  assert.equal(missing.view, 'history-error');
  if (missing.view === 'history-error') assert.equal(missing.status, 401);
  const crossOrigin = await prepareHistoricalRestoration(await dashboardRequest('restorePublication', selection, await token(), 'https://dashboard.test', 'https://attacker.test'),
    selection, environment, { keySource: accessKeySource });
  assert.equal(crossOrigin.view, 'history-error');
  if (crossOrigin.view === 'history-error') assert.equal(crossOrigin.status, 401);
  const publishWithoutAuth = await publishHistoricalRestoration(await dashboardRequest('publishRestoration', publicationForm({}), ''), publicationForm({}),
    environment, { keySource: accessKeySource });
  assert.equal(publishWithoutAuth.view, 'history-error');
  if (publishWithoutAuth.view === 'history-error') assert.equal(publishWithoutAuth.status, 401);
});

test('non-development targets stay read-only even for the approved founder', async () => {
  const production = { ...environment, CATALOG_ENVIRONMENT: 'production' };
  const loaded = await loadDashboard(new Request('https://dashboard.test/', {
    headers: { 'Cf-Access-Jwt-Assertion': await token() },
  }), production, { keySource: accessKeySource });
  assert.ok(loaded.source);
  const html = renderDashboard(undefined, loaded.source, production);
  assert.doesNotMatch(html, /Edit details|action="@editProgram"/);
  assert.match(html, /Editing and publication are disabled/);
  const submitted = form({ publication_fingerprint: loaded.source!.source_fingerprint });
  const result = await handleDashboardAction('review', await dashboardRequest('reviewProgram', submitted), submitted,
    production, { keySource: accessKeySource });
  assert.equal(result.view, 'error');
  if (result.view === 'error') assert.equal(result.status, 403);
});

test('complete-source review gives actionable structure, reference, duplicate-key, and identity errors', async () => {
  const baseline = await readCurrentSource();
  const selected = baseline.source.programs.find(program => program.removed !== true)!;
  const selectedSlot = selected.workouts.find(workout => workout.removed !== true)!.exercises.find(slot => slot.removed !== true)!;
  const secondExercise = baseline.source.exercises.find(exercise => exercise.key !== selectedSlot.exercise)!;
  const scenarios: Array<[string, (candidate: CatalogSource) => void, RegExp]> = [
    ['rep bounds', candidate => {
      const slot = candidate.programs.find(program => program.key === selected.key)!.workouts
        .flatMap(workout => workout.exercises).find(item => item.key === selectedSlot.key)!;
      slot.reps.minimum = slot.reps.maximum + 1;
    }, /rep bounds/],
    ['broken exercise reference', candidate => {
      candidate.programs.find(program => program.key === selected.key)!.workouts
        .flatMap(workout => workout.exercises).find(item => item.key === selectedSlot.key)!.exercise = 'missing-movement';
    }, /unknown exercise/],
    ['duplicate identity', candidate => {
      candidate.programs.push({ ...structuredClone(selected), name: 'Duplicate program identity' });
    }, /duplicate key/],
    ['movement identity conflict', candidate => {
      candidate.programs.find(program => program.key === selected.key)!.workouts
        .flatMap(workout => workout.exercises).find(item => item.key === selectedSlot.key)!.exercise = secondExercise.key;
    }, /cannot be reused for a different exercise/],
  ];
  for (const [label, mutate, expected] of scenarios) {
    const candidate = structuredClone(baseline.source);
    mutate(candidate);
    const submitted = form({ program_key: selected.key, publication_fingerprint: baseline.source_fingerprint,
      catalog_source: JSON.stringify(candidate) });
    const result = await handleDashboardAction('review', await dashboardRequest('reviewProgram', submitted), submitted,
      environment, { keySource: accessKeySource });
    assert.equal(result.view, 'edit', `${label} should return to the editor`);
    if (result.view === 'edit' && result.contentKind === 'program') assert.match(result.catalogErrors?.join(' ') ?? '', expected, label);
  }
});


test('stale reviews and transaction failures report errors and preserve the previous catalog', async () => {
  const accessToken = await token();
  const baseline = await readCurrentSource();
  const fields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'Stale Candidate' });
  const review = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, accessToken), fields,
    environment, { keySource: accessKeySource });
  assert.equal(review.view, 'review');
  if (review.view !== 'review' || review.contentKind !== 'program') return;

  const competitorFields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'CLI Candidate' });
  const competitorReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', competitorFields, accessToken), competitorFields,
    environment, { keySource: accessKeySource });
  assert.equal(competitorReview.view, 'review');
  if (competitorReview.view !== 'review' || competitorReview.contentKind !== 'program') return;
  const competitorPublishForm = await publishFields(competitorReview);
  const competitorPublished = await handleDashboardAction('publish', await dashboardRequest('publishProgram', competitorPublishForm, accessToken), competitorPublishForm,
    environment, { keySource: accessKeySource });
  assert.equal(competitorPublished.view, 'success');

  const staleForm = await publishFields(review);
  const stale = await handleDashboardAction('publish', await dashboardRequest('publishProgram', staleForm, accessToken), staleForm,
    environment, { keySource: accessKeySource });
  assert.equal(stale.view, 'error');
  if (stale.view === 'error') assert.equal(stale.status, 409);

  const latest = await readCurrentSource();
  const rollbackFields = form({ publication_fingerprint: latest.source_fingerprint, name: 'Rolled Back Candidate' });
  const rollbackReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', rollbackFields, accessToken), rollbackFields,
    environment, { keySource: accessKeySource });
  assert.equal(rollbackReview.view, 'review');
  if (rollbackReview.view !== 'review' || rollbackReview.contentKind !== 'program') return;
  transactionFailure = true;
  const rollbackForm = await publishFields(rollbackReview);
  const failed = await handleDashboardAction('publish', await dashboardRequest('publishProgram', rollbackForm, accessToken), rollbackForm,
    environment, { keySource: accessKeySource });
  transactionFailure = false;
  assert.equal(failed.view, 'error');
  if (failed.view === 'error') assert.equal(failed.status, 503);
  assert.equal((await readCurrentSource()).source.programs[1]!.name, 'CLI Candidate');
});

test('same reviewed publish retry is idempotent after the dashboard loses the first response', async () => {
  const accessToken = await token();
  const baseline = await readCurrentSource();
  const fields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'Retry Candidate' });
  const review = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, accessToken), fields,
    environment, { keySource: accessKeySource });
  assert.equal(review.view, 'review');
  if (review.view !== 'review' || review.contentKind !== 'program') return;
  const retryForm = await publishFields(review);
  const before = await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  const uncertain = await handleDashboardAction('publish', await dashboardRequest('publishProgram', retryForm, accessToken), retryForm,
    environment, {
      keySource: accessKeySource,
      fetcher: async (input, init) => {
        const response = await fetch(input, init);
        if (new URL(String(input)).pathname.endsWith('/publish')) throw new Error('simulated lost response after commit');
        return response;
      },
    });
  assert.equal(uncertain.view, 'error');
  if (uncertain.view === 'error') assert.equal(uncertain.status, 503);
  const retry = await handleDashboardAction('publish', await dashboardRequest('publishProgram', retryForm, accessToken), retryForm,
    environment, { keySource: accessKeySource });
  assert.equal(retry.view, 'success');
  const afterRetry = await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  assert.equal(Number(afterRetry.rows[0]?.count), Number(before.rows[0]?.count) + 1,
    'the uncertain first request creates one publication and the identical retry reuses it');
  assert.equal((await readCurrentSource()).source.programs[1]!.name, 'Retry Candidate');
});

test('visual artifacts can be captured for edit, review, success, and error states', async () => {
  const outputDirectory = process.env.DASHBOARD_SCREENSHOT_DIR;
  if (!outputDirectory) return;
  const chromePath = process.env.DASHBOARD_CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  await access(chromePath);
  await mkdir(outputDirectory, { recursive: true });
  const loaded = await loadDashboard(new Request('https://dashboard.test/', { headers: { 'Cf-Access-Jwt-Assertion': await token() } }),
    environment, { keySource: accessKeySource });
  assert.ok(loaded.source);
  const selected = loaded.source!.source.programs[1]!;
  const fields: ProgramFields = { program_key: selected.key, name: 'A considered program name', format: selected.format,
    emphasis: selected.emphasis, recommended_weeks: String(selected.recommended_weeks) };
  const edit: DashboardResult = { view: 'edit', contentKind: 'program', source: loaded.source!.source, publicationID: loaded.source!.publication_id,
    sourceFingerprint: loaded.source!.source_fingerprint, fields };
  const reviewRequest = form({ ...fields, publication_fingerprint: loaded.source!.source_fingerprint });
  const reviewed = await handleDashboardAction('review', await dashboardRequest('reviewProgram', reviewRequest), reviewRequest,
    environment, { keySource: accessKeySource });
  assert.equal(reviewed.view, 'review');
  const reviewEnvironment = { ...environment, CATALOG_REPOSITORY_OWNER: 'dimitarradulov',
    CATALOG_REPOSITORY_NAME: 'one-set', CATALOG_REPOSITORY_BRANCH: 'main' };
  assert.match(renderDashboard(reviewed, undefined, reviewEnvironment), /development catalog · repo dimitarradulov\/one-set · main/);
  const success: DashboardResult = { view: 'success', publicationID: 'publication-success-preview', repositoryStatus: 'synchronized', repositoryCommitSHA: 'abc123def456789' };
  const partialSync: DashboardResult = { view: 'success', publicationID: 'publication-partial-preview', repositoryStatus: 'failed', repositoryDetail: 'GitHub did not accept the update.' };
  const error: DashboardResult = { view: 'error', status: 503, title: 'Catalog service unavailable', detail: 'The catalog service could not prepare a review. Retry when the service is available.' };
  const states: Array<[string, DashboardResult | undefined, SourceResponse | undefined]> = [
    ['catalog', undefined, loaded.source],
    ['edit', edit, undefined], ['review', reviewed as DashboardResult, undefined],
    ['success', success, undefined], ['partial-sync', partialSync, undefined], ['error', error, undefined],
  ];
  const css = await readFile(new URL('../public/dashboard.css', import.meta.url), 'utf8');
  const browser = await chromium.launch({ executablePath: chromePath, headless: true, args: ['--no-sandbox'] });
  try {
    for (const [name, state, sourceData] of states) {
      const html = renderDashboard(state, sourceData, reviewEnvironment).replace('<link rel="stylesheet" href="/dashboard.css">', `<style>${css}</style>`)
        .replaceAll('action="@editProgram"', 'action="#"').replaceAll('action="@reviewProgram"', 'action="#"').replaceAll('action="@publishProgram"', 'action="#"').replaceAll('action="@syncCatalog"', 'action="#"');
      const htmlPath = resolve(outputDirectory, `issue-61-${name}.html`);
      await (await import('node:fs/promises')).writeFile(htmlPath, html);
      for (const [size, width, height] of [['laptop', 1440, 1100], ['mobile', 390, 844]] as const) {
        const page = await browser.newPage({ viewport: { width, height } });
        await page.goto(`file://${htmlPath}`);
        await page.evaluate(() => window.scrollTo(0, 0));
        const imagePath = resolve(outputDirectory, `issue-61-${name}-${size}.png`);
        await page.screenshot({ path: imagePath, fullPage: size === 'laptop' });
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }
});

test('real browser creates, edits, removes, and restores complete catalog structures', { timeout: 90_000 }, async t => {
  const chromePath = process.env.DASHBOARD_CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  try { await access(chromePath); } catch { t.skip('Set DASHBOARD_CHROME_BIN to run the local browser journey'); return; }
  const outputDirectory = process.env.DASHBOARD_SCREENSHOT_DIR;
  if (outputDirectory) await mkdir(outputDirectory, { recursive: true });
  const portServer = net.createServer();
  portServer.listen(0, '127.0.0.1');
  await once(portServer, 'listening');
  const browserPort = (portServer.address() as net.AddressInfo).port;
  await new Promise<void>((resolveClose, rejectClose) => portServer.close(error => error ? rejectClose(error) : resolveClose()));

  const baseConfigPath = new URL('../dist/server/wrangler.json', import.meta.url);
  const config = JSON.parse(await readFile(baseConfigPath, 'utf8')) as { name: string; compatibility_date: string; vars: Record<string, string> };
  config.name = 'oneset-catalog-dashboard-browser-test';
  config.compatibility_date = '2026-10-08';
  environment.ACCESS_TEAM_DOMAIN = apiOrigin;
  apiEnvironment.ACCESS_TEAM_DOMAIN = apiOrigin;
  config.vars = {
    CATALOG_ENVIRONMENT: 'development',
    CATALOG_API_BASE_URL: apiOrigin,
    CATALOG_PUBLISH_TOKEN: publisherToken,
    ACCESS_TEAM_DOMAIN: apiOrigin,
    ACCESS_AUDIENCE: audience,
    ACCESS_APPROVED_EMAIL: founder,
  };
  const e2eConfigPath = new URL('../dist/server/wrangler.e2e.json', import.meta.url);
  await writeFile(e2eConfigPath, JSON.stringify(config));
  const wranglerPath = resolve(new URL('../../worker/node_modules/.bin/wrangler', import.meta.url).pathname);
  const worker = spawn(wranglerPath, ['dev', '--config', e2eConfigPath.pathname, '--port', String(browserPort), '--ip', '127.0.0.1', '--local'], { stdio: 'ignore' });
  const workerExit = once(worker, 'exit');
  let browser: Awaited<ReturnType<typeof chromium.launch>> | undefined;
  try {
    const origin = `http://127.0.0.1:${browserPort}`;
    let ready = false;
    for (let attempt = 0; attempt < 60; attempt++) {
      try {
        const response = await fetch(origin);
        if (response.status === 401 || response.status === 200) { ready = true; break; }
      } catch { /* Wrangler is still starting. */ }
      await new Promise(resolveWait => setTimeout(resolveWait, 250));
    }
    assert.ok(ready, 'Astro Worker should become ready');
    const browserToken = await token(founder, apiOrigin);
    assert.equal(await verifyCloudflareAccess(new Request('https://dashboard.test/', {
      headers: { 'Cf-Access-Jwt-Assertion': browserToken },
    }), { ACCESS_TEAM_DOMAIN: apiOrigin, ACCESS_AUDIENCE: audience, ACCESS_APPROVED_EMAIL: founder }), true,
    'the local signed Access token should verify against the local cert endpoint');
    browser = await chromium.launch({ executablePath: chromePath, headless: true, args: ['--no-sandbox'] });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
    await page.setExtraHTTPHeaders({ 'Cf-Access-Jwt-Assertion': browserToken });
    const response = await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
    assert.equal(response?.status(), 200);
    await page.getByRole('button', { name: 'Create program' }).click();
    await page.getByLabel('Program name').waitFor();
    await page.getByLabel('Program name').fill('Browser-created structure');
    await page.getByLabel('Format').fill('2 workouts · full body');
    await page.getByLabel('Emphasis').fill('A complete browser-authored program.');
    await page.getByLabel('Recommended training weeks').fill('12');
    await page.getByRole('button', { name: 'Add workout template' }).click();
    const workoutCards = page.locator('.workout-card');
    assert.equal(await workoutCards.count(), 2);
    await workoutCards.nth(1).getByLabel('Workout name').fill('Workout B');
    await workoutCards.nth(1).getByLabel('Banner identifier').fill('issue-62-banner');
    await workoutCards.nth(1).locator('[data-slot-field="minimum"]').fill('9');
    await workoutCards.nth(1).locator('[data-slot-field="maximum"]').fill('13');
    await workoutCards.nth(1).getByLabel('Scope').selectOption('each_leg');
    await workoutCards.nth(1).getByRole('button', { name: 'Move workout up' }).click();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-62-browser-edit.png'), fullPage: true });

    await page.getByLabel('Program name').evaluate(input => input.removeAttribute('required'));
    await page.getByLabel('Program name').fill('');
    await page.getByRole('button', { name: 'Review complete program' }).click();
    const validationText = await page.locator('body').innerText();
    assert.match(validationText, /Enter a program name\./, `server validation should return the edit form; received: ${validationText}`);
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-62-browser-error.png'), fullPage: true });

    await page.getByLabel('Program name').fill('Browser-created structure');
    await page.getByRole('button', { name: 'Review complete program' }).click();
    await page.getByRole('heading', { name: 'Review complete catalog changes' }).waitFor();
    await page.locator('.proposed-structure').getByText('Banner issue-62-banner').waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-62-browser-review.png'), fullPage: true });

    await page.getByRole('button', { name: 'Back to editing' }).click();
    await page.getByLabel('Program name').waitFor();
    assert.equal(await page.getByLabel('Program name').inputValue(), 'Browser-created structure');
    assert.equal(await page.locator('.workout-card').count(), 2);
    assert.equal(await page.locator('.workout-card').first().getByLabel('Workout name').inputValue(), 'Workout B');
    await page.getByRole('button', { name: 'Review complete program' }).click();
    await page.getByRole('heading', { name: 'Review complete catalog changes' }).waitFor();
    await page.getByRole('button', { name: 'Publish to development' }).click();
    await page.getByRole('heading', { name: 'Catalog published' }).waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-62-browser-success.png'), fullPage: true });
    const created = (await readCurrentSource()).source.programs.find(program => program.name === 'Browser-created structure');
    assert.ok(created, 'the complete new program should be published');
    assert.equal(created.workouts.length, 2);
    assert.deepEqual(created.workouts.map(workout => workout.position), [1, 2]);
    assert.equal(created.workouts[0]!.banner, 'issue-62-banner');
    assert.equal(created.workouts[0]!.exercises[0]!.reps.minimum, 9);
    assert.equal(created.workouts[0]!.exercises[0]!.scope, 'each_leg');
    const appCreated = (await readAppCatalog()).programs.find(program => program.key === created.key)!;
    assert.deepEqual(appCreated.workouts.map(workout => workout.position), [1, 2]);
    assert.equal(appCreated.workouts[0]!.banner, 'issue-62-banner');
    assert.equal(appCreated.workouts[0]!.exercises[0]!.reps.minimum, 9);
    assert.equal(appCreated.workouts[0]!.exercises[0]!.scope, 'each_leg');

    await page.getByRole('link', { name: 'Return to catalog' }).click();
    await page.getByRole('button', { name: 'Edit details' }).nth(1).click();
    await page.getByLabel('Program name').waitFor();
    const existingProgramKey = (await readCurrentSource()).source.programs[1]!.key;
    const existingWorkouts = page.locator('.workout-card');
    assert.ok(await existingWorkouts.count() >= 2);
    const beforeOrder = await existingWorkouts.evaluateAll(rows => rows.map(row => row.querySelector('code')?.textContent));
    await existingWorkouts.first().getByRole('button', { name: 'Move workout down' }).click();
    const selectedRow = page.locator('.workout-card').first().locator('.slot-row').first();
    const originalSlotKey = await selectedRow.getAttribute('data-slot');
    const originalExercise = await selectedRow.locator('[data-slot-field="exercise"]').inputValue();
    const replacementExercise = (await readCurrentSource()).source.exercises.find(exercise => exercise.key !== originalExercise)!.key;
    const beforePrescription = await selectedRow.locator('[data-slot-field="minimum"]').inputValue();
    await page.locator('.workout-card').first().locator('.slot-row').first().locator('[data-slot-field="minimum"]').fill('5');
    await page.locator('.workout-card').first().locator('.slot-row').first().locator('[data-slot-field="maximum"]').fill('6');
    await page.locator('.workout-card').first().locator('.slot-row').first().locator('[data-slot-field="exercise"]').selectOption(replacementExercise);
    await page.getByRole('button', { name: 'Review complete program' }).click();
    await page.getByRole('heading', { name: 'Review complete catalog changes' }).waitFor();
    assert.equal(await page.getByRole('button', { name: 'Publish to development' }).isEnabled(), true);
    await page.getByRole('button', { name: 'Publish to development' }).click();
    await page.getByRole('heading', { name: 'Catalog published' }).waitFor();
    const updated = (await readCurrentSource()).source.programs.find(program => program.key === existingProgramKey)!;
    assert.notDeepEqual(updated.workouts.map(workout => workout.key), beforeOrder);
    assert.equal(updated.workouts[0]!.exercises[0]!.reps.minimum, 5);
    assert.equal(updated.workouts[0]!.exercises[0]!.reps.maximum, 6);
    assert.notEqual(beforePrescription, '5');
    assert.notEqual(updated.workouts[0]!.exercises[0]!.key, originalSlotKey,
      'a changed movement receives a new stable slot identity');
    assert.equal(updated.workouts[0]!.exercises[0]!.exercise, replacementExercise);
    assert.equal(updated.workouts.flatMap(workout => workout.exercises).find(slot => slot.key === originalSlotKey)?.removed, true,
      'the prior slot identity remains represented as removed');
    const appUpdated = (await readAppCatalog()).programs.find(program => program.key === existingProgramKey)!;
    assert.deepEqual(appUpdated.workouts.map(workout => workout.key), updated.workouts.filter(workout => !workout.removed).map(workout => workout.key));
    assert.deepEqual(appUpdated.workouts.map(workout => workout.position), updated.workouts.filter(workout => !workout.removed).map(workout => workout.position));
    assert.equal(appUpdated.workouts[0]!.exercises[0]!.reps.minimum, 5);
    assert.equal(appUpdated.workouts[0]!.exercises[0]!.reps.maximum, 6);
    assert.equal(appUpdated.workouts[0]!.exercises[0]!.exercise, replacementExercise);

    const stableProgramKey = updated.key;
    const stableWorkoutKey = updated.workouts[0]!.key;
    const stableSlotKey = updated.workouts[0]!.exercises[0]!.key;
    const openEditor = async () => {
      await page.getByRole('link', { name: 'Return to catalog' }).click();
      await page.getByRole('button', { name: 'Edit details' }).nth(1).click();
      await page.getByLabel('Program name').waitFor();
    };
    const reviewAndPublish = async (changeKind: string) => {
      await page.getByRole('button', { name: 'Review complete program' }).click();
      await page.getByRole('heading', { name: 'Review complete catalog changes' }).waitFor();
      assert.ok((await page.locator('.diff-list').innerText()).toLowerCase().includes(changeKind),
        `review should explicitly show ${changeKind}`);
      if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, `issue-64-${changeKind.replaceAll(' ', '-')}-review.png`), fullPage: true });
      await page.getByRole('button', { name: 'Publish to development' }).click();
      await page.getByRole('heading', { name: 'Catalog published' }).waitFor();
    };

    await openEditor();
    await page.locator('.workout-card').first().locator('.slot-list .slot-row').first().getByRole('button', { name: 'Remove slot' }).click();
    await reviewAndPublish('remove exercise slot');
    let retained = (await readCurrentSource()).source.programs.find(program => program.key === stableProgramKey)!;
    assert.equal(retained.workouts.flatMap(workout => workout.exercises).find(slot => slot.key === stableSlotKey)?.removed, true,
      'removing a slot retains its original stable identity');
    assert.equal((await readAppCatalog()).programs.find(program => program.key === stableProgramKey)!.workouts
      .flatMap(workout => workout.exercises).some(slot => slot.key === stableSlotKey), false,
    'removed slots are absent from app-facing active prescriptions');

    await openEditor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-64-retained-slot-restore-control.png'), fullPage: true });
    await page.locator(`.retained-slot-rows [data-slot="${stableSlotKey}"]`).getByRole('button', { name: 'Restore slot' }).click();
    await reviewAndPublish('restore exercise slot');
    retained = (await readCurrentSource()).source.programs.find(program => program.key === stableProgramKey)!;
    assert.equal(retained.workouts.flatMap(workout => workout.exercises).find(slot => slot.key === stableSlotKey)?.removed, undefined,
      'restoring a slot reuses its original identity');
    assert.ok((await readAppCatalog()).programs.find(program => program.key === stableProgramKey)!.workouts
      .flatMap(workout => workout.exercises).some(slot => slot.key === stableSlotKey));

    await openEditor();
    await page.locator(`.workout-card[data-workout="${stableWorkoutKey}"]`).getByRole('button', { name: 'Remove template' }).click();
    assert.match(await page.locator('#removed-workout-list > summary').innerText(), /1 removed workout template/);
    assert.notEqual(await page.locator('#removed-workout-list').getAttribute('open'), null,
      'removing a template exposes its restore action immediately');
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-64-removed-workout-restore-control.png'), fullPage: true });
    await reviewAndPublish('remove workout');
    retained = (await readCurrentSource()).source.programs.find(program => program.key === stableProgramKey)!;
    assert.equal(retained.workouts.find(workout => workout.key === stableWorkoutKey)?.removed, true,
      'removing a workout retains its original stable identity');
    assert.equal((await readAppCatalog()).programs.find(program => program.key === stableProgramKey)!.workouts
      .some(workout => workout.key === stableWorkoutKey), false);

    await openEditor();
    await page.locator(`#removed-workout-list [data-workout="${stableWorkoutKey}"]`).getByRole('button', { name: 'Restore template' }).click();
    assert.match(await page.locator('#removed-workout-list > summary').innerText(), /0 removed workout template/);
    await reviewAndPublish('restore workout');
    retained = (await readCurrentSource()).source.programs.find(program => program.key === stableProgramKey)!;
    assert.equal(retained.workouts.find(workout => workout.key === stableWorkoutKey)?.removed, undefined,
      'restoring a workout reuses its original identity');
    assert.ok((await readAppCatalog()).programs.find(program => program.key === stableProgramKey)!.workouts
      .some(workout => workout.key === stableWorkoutKey));

    const programCount = (await readCurrentSource()).source.programs.length;
    await openEditor();
    await page.getByRole('button', { name: 'Remove program' }).click();
    await reviewAndPublish('remove program');
    retained = (await readCurrentSource()).source.programs.find(program => program.key === stableProgramKey)!;
    assert.equal(retained.removed, true, 'program removal retains its original identity');
    assert.equal((await readCurrentSource()).source.programs.filter(program => program.key === stableProgramKey).length, 1,
      'program removal does not create a duplicate');
    assert.equal((await readAppCatalog()).programs.find(program => program.key === stableProgramKey)?.removed, true,
      'removed program remains in the app catalog for existing followers but is marked unavailable');
    assert.match(await page.locator('body').innerText(), /Catalog published/);

    await openEditor();
    assert.match(await page.locator('.panel-heading').innerText(), /Removed/);
    await page.getByRole('button', { name: 'Restore program' }).click();
    await reviewAndPublish('restore program');
    const restoredProgram = (await readCurrentSource()).source.programs.find(program => program.key === stableProgramKey)!;
    assert.equal(restoredProgram.removed, undefined, 'restoring makes the same program identity available again');
    assert.equal((await readCurrentSource()).source.programs.length, programCount,
      'restoration does not create a duplicate program');
    assert.equal((await readAppCatalog()).programs.filter(program => program.key === stableProgramKey).length, 1);
  } finally {
    await browser?.close();
    worker.kill('SIGTERM');
    await workerExit.catch(() => undefined);
    await (await import('node:fs/promises')).unlink(e2eConfigPath.pathname).catch(() => undefined);
  }
});

test('real browser inspects an older publication, shows a stale correction, and publishes a reconciled new version', { timeout: 90_000 }, async t => {
  const chromePath = process.env.DASHBOARD_CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  try { await access(chromePath); } catch { t.skip('Set DASHBOARD_CHROME_BIN to run the local browser journey'); return; }
  const outputDirectory = process.env.DASHBOARD_SCREENSHOT_DIR;
  if (outputDirectory) await mkdir(outputDirectory, { recursive: true });
  const portServer = net.createServer();
  portServer.listen(0, '127.0.0.1');
  await once(portServer, 'listening');
  const browserPort = (portServer.address() as net.AddressInfo).port;
  await new Promise<void>((resolveClose, rejectClose) => portServer.close(error => error ? rejectClose(error) : resolveClose()));

  const configPath = new URL('../dist/server/wrangler.json', import.meta.url);
  const config = JSON.parse(await readFile(configPath, 'utf8')) as { name: string; compatibility_date: string; vars: Record<string, string> };
  config.name = 'oneset-catalog-history-browser-test';
  config.compatibility_date = '2026-10-08';
  environment.ACCESS_TEAM_DOMAIN = apiOrigin;
  apiEnvironment.ACCESS_TEAM_DOMAIN = apiOrigin;
  config.vars = { CATALOG_ENVIRONMENT: 'development', CATALOG_API_BASE_URL: apiOrigin,
    CATALOG_PUBLISH_TOKEN: publisherToken, ACCESS_TEAM_DOMAIN: apiOrigin, ACCESS_AUDIENCE: audience, ACCESS_APPROVED_EMAIL: founder };
  const e2eConfigPath = new URL('../dist/server/wrangler.history-e2e.json', import.meta.url);
  await writeFile(e2eConfigPath, JSON.stringify(config));
  const wranglerPath = resolve(new URL('../../worker/node_modules/.bin/wrangler', import.meta.url).pathname);
  const worker = spawn(wranglerPath, ['dev', '--config', e2eConfigPath.pathname, '--port', String(browserPort), '--ip', '127.0.0.1', '--local'], { stdio: 'ignore' });
  const workerExit = once(worker, 'exit');
  let browser: Awaited<ReturnType<typeof chromium.launch>> | undefined;
  try {
    const origin = `http://127.0.0.1:${browserPort}`;
    let ready = false;
    for (let attempt = 0; attempt < 60; attempt++) {
      try { const response = await fetch(origin); if (response.status === 401 || response.status === 200) { ready = true; break; } }
      catch { /* Wrangler is still starting. */ }
      await new Promise(resolveWait => setTimeout(resolveWait, 250));
    }
    assert.ok(ready, 'Astro Worker should become ready');
    const browserToken = await token(founder, apiOrigin);
    browser = await chromium.launch({ executablePath: chromePath, headless: true, args: ['--no-sandbox'] });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
    await page.setExtraHTTPHeaders({ 'Cf-Access-Jwt-Assertion': browserToken });
    const selectedURL = `${origin}/history?publication_id=publication-history-browser`;
    const inspected = await page.goto(selectedURL, { waitUntil: 'networkidle' });
    assert.equal(inspected?.status(), 200);
    const inspectionText = await page.locator('body').innerText();
    assert.match(inspectionText, /Inspect publication/, `history page should render the selected publication; got: ${inspectionText.slice(0, 1200)}`);
    assert.match(inspectionText, /Upper \/ Lower Browser Historical/);
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-65-history-inspection.png'), fullPage: true });

    await page.getByRole('button', { name: 'Prepare correction from this publication' }).click();
    await page.getByRole('heading', { name: 'Review historical correction' }).waitFor();
    assert.match(await page.locator('body').innerText(), /Reconciliation kept newer identities/);
    assert.match(await page.locator('body').innerText(), /Affected programs/);
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-65-history-review.png'), fullPage: true });

    const current = await readCurrentSource();
    const competitorFields = form({ program_key: current.source.programs[2]!.key, name: 'Browser competing edit',
      publication_fingerprint: current.source_fingerprint });
    const competitorReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', competitorFields, browserToken), competitorFields,
      environment, { keySource: accessKeySource });
    assert.equal(competitorReview.view, 'review');
    if (competitorReview.view !== 'review' || competitorReview.contentKind !== 'program') return;
    const competitorPublishForm = await publishFields(competitorReview);
    const competitorPublished = await handleDashboardAction('publish', await dashboardRequest('publishProgram', competitorPublishForm, browserToken),
      competitorPublishForm, environment, { keySource: accessKeySource });
    assert.equal(competitorPublished.view, 'success');

    await page.getByRole('button', { name: 'Publish correction' }).click();
    await page.getByRole('heading', { name: 'Catalog changed before publication' }).waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-65-history-stale.png'), fullPage: true });

    await page.goto(selectedURL, { waitUntil: 'networkidle' });
    await page.getByRole('button', { name: 'Prepare correction from this publication' }).click();
    await page.getByRole('heading', { name: 'Review historical correction' }).waitFor();
    transactionFailure = true;
    await page.getByRole('button', { name: 'Publish correction' }).click();
    await page.getByRole('heading', { name: 'Publication failed' }).waitFor();
    await page.getByRole('button', { name: 'Retry this publication' }).waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-65-history-failure.png'), fullPage: true });
    transactionFailure = false;
    await page.getByRole('button', { name: 'Retry this publication' }).click();
    await page.getByRole('heading', { name: /Correction published; repository sync needed/ }).waitFor();
    await page.getByRole('button', { name: 'Retry repository sync' }).waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-65-history-success.png'), fullPage: true });
    const after = await readCurrentSource();
    assert.equal(after.source.programs[1]!.name, 'Upper / Lower Browser Historical');
    assert.ok(after.source.programs.some(program => program.key === source.programs.at(-1)!.key), 'a program added after the historical publication remains present');
    const publicationCountBeforeSyncRetry = Number((await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`)).rows[0]?.count);
    await page.getByRole('button', { name: 'Retry repository sync' }).click();
    await page.getByRole('heading', { name: /Correction published; repository sync needed/ }).waitFor();
    const publicationCountAfterSyncRetry = Number((await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`)).rows[0]?.count);
    assert.equal(publicationCountAfterSyncRetry, publicationCountBeforeSyncRetry, 'repository retry does not create another correction publication');
  } finally {
    await browser?.close();
    worker.kill('SIGTERM');
    await workerExit.catch(() => undefined);
    await (await import('node:fs/promises')).unlink(e2eConfigPath.pathname).catch(() => undefined);
  }
});

function githubHarness() {
  type File = { sha: string; content: string };
  const trees = new Map<string, Map<string, File>>([['tree-0', new Map([['README.md', { sha: 'readme-blob', content: 'unrelated repository work\n' }]])]]);
  const commits = new Map<string, { tree: string; parents: string[] }>([['head-0', { tree: 'tree-0', parents: [] }]]);
  let branch = 'head-0';
  let counter = 0;
  let conflictNextUpdate = false;
  let refUpdates = 0;
  return {
    get branch() { return branch; },
    get refUpdates() { return refUpdates; },
    conflictOnce() { conflictNextUpdate = true; },
    async fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
      const url = new URL(String(input));
      const path = url.pathname.replace(/^\/repos\/[^/]+\/[^/]+/, '');
      const method = init?.method ?? 'GET';
      const body = init?.body ? JSON.parse(String(init.body)) as Record<string, unknown> : {};
      if (path === '/git/ref/heads/main' && method === 'GET') {
        return Response.json({ object: { sha: branch } });
      }
      if (path.startsWith('/git/trees/') && method === 'GET') {
        const sha = decodeURIComponent(path.split('/').at(-1)!.split('?')[0]!);
        const tree = trees.get(sha);
        if (!tree) return Response.json({ message: 'missing tree' }, { status: 404 });
        return Response.json({ tree: [...tree.keys()].map(filePath => ({ path: filePath, sha: tree.get(filePath)!.sha })) });
      }
      if (path.startsWith('/git/blobs/') && method === 'GET') {
        const sha = decodeURIComponent(path.split('/').at(-1)!);
        const file = [...trees.values()].flatMap(tree => [...tree.values()]).find(value => value.sha === sha);
        return file ? Response.json({ encoding: 'base64', content: Buffer.from(file.content).toString('base64') })
          : Response.json({ message: 'missing blob' }, { status: 404 });
      }
      if (path.startsWith('/git/commits/') && method === 'GET') {
        const commit = commits.get(decodeURIComponent(path.split('/').at(-1)!));
        return commit ? Response.json({ tree: { sha: commit.tree } }) : Response.json({ message: 'missing commit' }, { status: 404 });
      }
      if (path === '/git/trees' && method === 'POST') {
        const baseTree = trees.get(String(body.base_tree));
        if (!baseTree) return Response.json({ message: 'missing base tree' }, { status: 404 });
        const next = new Map(baseTree);
        for (const entry of body.tree as Array<{ path: string; sha?: string | null; content?: string }>) {
          if (entry.sha === null) next.delete(entry.path);
          else next.set(entry.path, { sha: `blob-${++counter}`, content: entry.content ?? '' });
        }
        const sha = `tree-${counter}`;
        trees.set(sha, next);
        return Response.json({ sha });
      }
      if (path === '/git/commits' && method === 'POST') {
        const sha = `commit-${++counter}`;
        commits.set(sha, { tree: String(body.tree), parents: body.parents as string[] });
        return Response.json({ sha });
      }
      if (path === '/git/refs/heads/main' && method === 'PATCH') {
        refUpdates++;
        if (conflictNextUpdate) {
          conflictNextUpdate = false;
          const externalTree = new Map(trees.get(commits.get(branch)!.tree)!);
          externalTree.set('notes/unrelated.md', { sha: 'unrelated-blob', content: 'kept\n' });
          trees.set('external-tree', externalTree);
          commits.set('external-head', { tree: 'external-tree', parents: [branch] });
          branch = 'external-head';
          return Response.json({ message: 'reference moved' }, { status: 409 });
        }
        if (commits.get(String(body.sha))?.parents[0] !== branch) {
          return Response.json({ message: 'not fast forward' }, { status: 422 });
        }
        branch = String(body.sha);
        return Response.json({ object: { sha: branch } });
      }
      return Response.json({ message: `unexpected ${method} ${path}` }, { status: 404 });
    },
    file(path: string): string | undefined {
      const treeSHA = commits.get(branch)!.tree;
      return trees.get(treeSHA)?.get(path)?.content;
    },
    parent(sha: string): string | undefined { return commits.get(sha)?.parents[0]; },
  };
}

async function publishSource(sourceToPublish: CatalogSource): Promise<string> {
  const sourceFingerprint = (await import('node:crypto')).createHash('sha256').update(JSON.stringify(sourceToPublish)).digest('hex');
  const previewResponse = await fetch(`${apiOrigin}/v1/maintenance/catalog/preview`, {
    method: 'POST', headers: { Authorization: `Bearer ${publisherToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ source: sourceToPublish, source_fingerprint: sourceFingerprint }),
  });
  assert.equal(previewResponse.status, 200);
  const preview = await previewResponse.json() as { preview_id: string; backend_fingerprint: string };
  const response = await fetch(`${apiOrigin}/v1/maintenance/catalog/publish`, {
    method: 'POST', headers: { Authorization: `Bearer ${publisherToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ source: sourceToPublish, source_fingerprint: sourceFingerprint, ...preview }),
  });
  assert.equal(response.status, 200);
  return (await response.json() as { publication_id: string }).publication_id;
}

test('repository synchronization generates exact catalog files, retries safely, and preserves concurrent edits', async () => {
  const current = await readCurrentSource();
  const harness = githubHarness();
  const syncEnvironment = Object.assign(environment, {
    CATALOG_REPOSITORY_OWNER: 'owner', CATALOG_REPOSITORY_NAME: 'one-set',
    CATALOG_REPOSITORY_BRANCH: 'main', CATALOG_REPOSITORY_TOKEN: 'server-only-token',
  });
  const synced = await synchronizePublication(current.publication_id, syncEnvironment, { githubFetch: harness.fetch });
  assert.equal(synced.status, 'synchronized', synced.detail ?? '');
  assert.equal(harness.file('README.md'), 'unrelated repository work\n');
  assert.equal(harness.file('OneSet/Services/Catalog/BundledProgramCatalog.swift'),
    catalogSourceFiles(current.source, current.publication_id, current.source_fingerprint)['OneSet/Services/Catalog/BundledProgramCatalog.swift']);
  assert.deepEqual(parse(harness.file('worker/catalog/exercises.yaml')!, { uniqueKeys: true }), { exercises: current.source.exercises });
  for (const [index, program] of current.source.programs.entries()) {
    const path = `worker/catalog/programs/${String(index + 1).padStart(2, '0')}-${program.key}.yaml`;
    assert.deepEqual(parse(harness.file(path)!, { uniqueKeys: true }), program);
  }

  const completedCommit = harness.branch;
  const updates = harness.refUpdates;
  const repeated = await synchronizePublication(current.publication_id, syncEnvironment, { githubFetch: harness.fetch });
  assert.equal(repeated.status, 'synchronized');
  assert.equal(harness.branch, completedCommit);
  assert.equal(harness.refUpdates, updates, 'a repeated request recognizes the exact publication marker');

  const reordered = structuredClone(current.source);
  reordered.programs[0]!.name += ' Repository conflict retry';
  const nextPublicationID = await publishSource(reordered);
  harness.conflictOnce();
  const conflictRetry = await synchronizePublication(nextPublicationID, syncEnvironment, { githubFetch: harness.fetch });
  assert.equal(conflictRetry.status, 'synchronized', conflictRetry.detail ?? '');
  assert.equal(harness.parent(harness.branch), 'external-head', 'retry rebases its intended catalog files on the latest repository head');
  assert.equal(harness.file('notes/unrelated.md'), 'kept\n');
});

test('repository synchronization reports generation failure, partial completion, and stale work without changing newer source', async () => {
  const harness = githubHarness();
  const syncEnvironment = Object.assign(environment, {
    CATALOG_REPOSITORY_OWNER: 'owner', CATALOG_REPOSITORY_NAME: 'one-set',
    CATALOG_REPOSITORY_BRANCH: 'main', CATALOG_REPOSITORY_TOKEN: 'server-only-token',
  });

  const baseline = await readCurrentSource();
  const founderToken = await token(founder, apiOrigin);
  const candidateFields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'Database live while export failed' });
  const review = await handleDashboardAction('review', await dashboardRequest('reviewProgram', candidateFields, founderToken),
    candidateFields, syncEnvironment, { keySource: accessKeySource });
  assert.equal(review.view, 'review', review.view === 'error' ? `${review.status} ${review.title}: ${review.detail}` : 'unexpected review result');
  if (review.view !== 'review' || review.contentKind !== 'program') return;
  const publishForm = await publishFields(review);
  const partial = await handleDashboardAction('publish', await dashboardRequest('publishProgram', publishForm, founderToken),
    publishForm, syncEnvironment, {
      keySource: accessKeySource,
      repositorySyncDependencies: { githubFetch: async () => Response.json({ message: 'transport unavailable' }, { status: 503 }) },
    });
  assert.equal(partial.view, 'success');
  if (partial.view !== 'success') return;
  assert.equal(partial.repositoryStatus, 'failed');
  const existing = await readCurrentSource();
  assert.equal(existing.source.programs[1]!.name, 'Database live while export failed');
  const partialPage = renderDashboard(partial, undefined, syncEnvironment);
  assert.match(partialPage, /database publication completed and remains live/i);
  assert.match(partialPage, /Retry repository sync/);
  const loadedAgain = await loadDashboard(new Request('https://dashboard.test/', {
    headers: { 'Cf-Access-Jwt-Assertion': founderToken },
  }), syncEnvironment, { keySource: accessKeySource });
  assert.equal(loadedAgain.source?.repository_sync_status, 'failed');
  assert.match(renderDashboard(undefined, loadedAgain.source, syncEnvironment), /Retry repository sync/);

  await database.query(`UPDATE public.catalog_publications SET source_document = $2::jsonb WHERE id = $1`, [
    existing.publication_id, JSON.stringify({ ...existing.source, exercises: [] }),
  ]);
  const generationFailure = await synchronizePublication(existing.publication_id, syncEnvironment, { githubFetch: harness.fetch });
  assert.equal(generationFailure.status, 'failed');
  assert.match(generationFailure.detail ?? '', /validation/i);
  await database.query(`UPDATE public.catalog_publications SET source_document = $2::jsonb WHERE id = $1`, [
    existing.publication_id, JSON.stringify(existing.source),
  ]);

  const newSource = structuredClone(existing.source);
  newSource.programs[0]!.name += ' Competing publication';
  const newerID = await publishSource(newSource);
  const branchBefore = harness.branch;
  const delayed = await synchronizePublication(existing.publication_id, syncEnvironment, { githubFetch: harness.fetch });
  assert.equal(delayed.status, 'superseded');
  assert.equal(harness.branch, branchBefore, 'delayed work for an older publication cannot write the repository');

  const preUpdate = harness.branch;
  const raced = await synchronizePublication(newerID, syncEnvironment, {
    githubFetch: harness.fetch,
    beforeReferenceUpdate: async () => {
      const competing = structuredClone(newSource);
      competing.programs[0]!.name += ' Newest publication';
      await publishSource(competing);
    },
  });
  assert.equal(raced.status, 'superseded');
  assert.equal(harness.branch, preUpdate, 'the current publication is rechecked immediately before the ref update');

  const latest = await readCurrentSource();
  const page = await loadDashboard(new Request('https://dashboard.test/', { headers: { 'Cf-Access-Jwt-Assertion': founderToken } }),
    environment, { keySource: accessKeySource });
  assert.equal(page.source?.publication_id, latest.publication_id);
  assert.equal(page.source?.source.programs[0]!.name, latest.source.programs[0]!.name);
});
