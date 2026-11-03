import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { readFile } from 'node:fs/promises';
import { handleHistoryRequest, type HistoryDatabase } from '../src/history.ts';

const issuer = 'https://clerk.test';
const keys = await generateKeyPair('RS256', { extractable: true });
const env = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(keys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
};

async function token(subject = 'history_user') {
  return new SignJWT({ sid: `session-${subject}` })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setSubject(subject)
    .setIssuer(issuer).setIssuedAt().setNotBefore('0s').setExpirationTime('1m')
    .sign(keys.privateKey);
}

const engine = new PGlite();
const database: HistoryDatabase = {
  query: async (sql, params) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
};

const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await engine.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await engine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await engine.exec(`INSERT INTO workout_programs (id, name) VALUES (10, 'Machine Full Body');`);
await engine.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/004_offered_program_onboarding.sql', 'utf8'));
await engine.exec(`
  INSERT INTO workouts (id, name, authoring_key) VALUES (100, 'Current A', 'day-a');
  INSERT INTO program_workouts (program_id, workout_id, position) VALUES (10, 100, 1);
  INSERT INTO exercises (id, name, instructions, reps_min, reps_max, rest_seconds,
      warmup_guidance, authoring_key) VALUES
    (100, 'Current exercise', 'Current instructions', 8, 12, 120,
      '{"steps":[],"note":"Current warmup"}', 'current-exercise');
  INSERT INTO workout_exercises (id, workout_id, exercise_id, position, reps_min, reps_max,
      authoring_key, rep_scope) VALUES
    (100, 100, 100, 1, 8, 12, 'current-slot', 'reps'),
    (101, 100, 100, 2, 8, 12, 'current-slot-b', 'reps');
  SELECT setval(pg_get_serial_sequence('workout_programs', 'id'), 10);
  SELECT setval(pg_get_serial_sequence('workouts', 'id'), 100);
  SELECT setval(pg_get_serial_sequence('exercises', 'id'), 100);
  SELECT setval(pg_get_serial_sequence('workout_exercises', 'id'), 100);
`);
await engine.exec(await readFile('../docs/database/migrations/005_cycle_workout_boundaries.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/006_completed_session_write.sql', 'utf8'));
await engine.exec(await readFile('../docs/database/migrations/007_completed_session_day_history.sql', 'utf8'));
await engine.exec(`
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES
    (1, 'history_user', 'kg', 2), (2, 'other_history_user', 'lb', 2);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at) VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 10, now()),
    ('22222222-2222-4222-8222-222222222222', 2, 10, now());
  INSERT INTO workout_sessions (id, user_program_id, workout_id, week_number, day_number,
      workout_name, started_at, completed_at, note) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 100, 3, 1,
      'Captured A', '2026-10-01T10:00:00Z', '2026-10-01T10:45:00Z', 'Kept note'),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111111', 100, 3, 1,
      'Captured B', '2026-10-01T10:00:00Z', '2026-10-01T10:50:00Z', NULL),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '11111111-1111-4111-8111-111111111111', 100, 2, NULL,
      'Older A', '2026-09-01T10:00:00Z', '2026-09-01T10:45:00Z', NULL),
    ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '22222222-2222-4222-8222-222222222222', 100, 1, 1,
      'Foreign session', '2026-11-01T10:00:00Z', '2026-11-01T10:45:00Z', 'Foreign note'),
    ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', '11111111-1111-4111-8111-111111111111', 100, 4, 1,
      'Active session', '2026-11-02T10:00:00Z', NULL, NULL);
  INSERT INTO workout_session_sets (workout_session_id, position, workout_exercise_id, exercise_id,
      prescription, weight, unit, reps, completed_at) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 1, 100, 100,
      '{"name":"Captured movement","instructions":"Captured guidance","stopping_guidance":"Captured stopping","warmup_guidance":{"steps":[],"note":"Captured warmup"},"video_key":null,"reps_min":8,"reps_max":12,"rep_scope":"each_side","rest_seconds":135}',
      72.500, 'lb', 10, '2026-10-01T10:12:00Z'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 2, 101, 100,
      '{"name":"Captured skipped movement","instructions":"Old instructions","stopping_guidance":"Stop","warmup_guidance":{"steps":[],"note":"Old warmup"},"video_key":null,"reps_min":8,"reps_max":12,"rep_scope":"reps","rest_seconds":120}',
      NULL, 'lb', NULL, NULL),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 1, 100, 100,
      '{"name":"Captured B movement","instructions":"Captured B guidance","stopping_guidance":"Stop","warmup_guidance":{"steps":[],"note":"Warmup"},"video_key":null,"reps_min":8,"reps_max":12,"rep_scope":"reps","rest_seconds":120}',
      0, 'kg', 8, '2026-10-01T10:20:00Z'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 1, 100, 100,
      '{"name":"Older captured movement","instructions":"Older guidance","stopping_guidance":"Stop","warmup_guidance":{"steps":[],"note":"Warmup"},"video_key":null,"reps_min":8,"reps_max":12,"rep_scope":"reps","rest_seconds":120}',
      40, 'kg', 9, '2026-09-01T10:20:00Z'),
    ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1, 100, 100,
      '{"name":"Foreign movement","instructions":"Private","stopping_guidance":"Stop","warmup_guidance":{"steps":[],"note":"Warmup"},"video_key":null,"reps_min":8,"reps_max":12,"rep_scope":"reps","rest_seconds":120}',
      100, 'lb', 10, '2026-11-01T10:20:00Z');
`);

after(async () => { await engine.close(); });

function request(bearer: string | undefined, query = '') {
  return new Request(`https://api.oneset.test/v1/sessions${query}`, {
    headers: bearer ? { Authorization: `Bearer ${bearer}` } : {},
  });
}

function foreignCursor() {
  const bytes = new TextEncoder().encode(JSON.stringify({
    version: 1,
    owner: 'other_history_user',
    startedAt: '2026-10-01T10:00:00.000000Z',
    sessionID: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  }));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/u, '');
}

test('history requires account authentication and marks the response private', async () => {
  const unauthenticated = await handleHistoryRequest(request(undefined), env, database);
  assert.equal(unauthenticated.status, 401);

  const response = await handleHistoryRequest(request(await token()), env, database);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'private, no-store');
});

test('history pages are bounded, newest-first, tie-stable, and include captured partial detail', async () => {
  const first = await handleHistoryRequest(request(await token(), '?limit=2'), env, database);
  assert.equal(first.status, 200);
  const firstPage = await first.json() as {
    sessions: Record<string, unknown>[]; next_cursor: string | null; has_more: boolean;
  };
  assert.equal(firstPage.has_more, true);
  assert.ok(firstPage.next_cursor);
  assert.deepEqual(firstPage.sessions.map(session => session.session_id), [
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  ]);

  const session = firstPage.sessions[1]!;
  assert.equal(session.program_name, 'Machine Full Body');
  assert.equal(session.workout_name, 'Captured A');
  assert.equal(session.week_number, 3);
  assert.equal(session.day_number, 1);
  assert.equal(session.note, 'Kept note');
  assert.equal(session.started_at, '2026-10-01T10:00:00.000000Z');
  assert.equal(session.completed_at, '2026-10-01T10:45:00.000000Z');
  assert.deepEqual(session.sets, [
    {
      workout_exercise_key: 'current-slot', exercise_key: 'current-exercise', position: 1,
      prescription: {
        name: 'Captured movement', instructions: 'Captured guidance', stopping_guidance: 'Captured stopping',
        warmup_guidance: { steps: [], note: 'Captured warmup' }, video_key: null,
        reps_min: 8, reps_max: 12, rep_scope: 'each_side', rest_seconds: 135,
      },
      weight: '72.500', unit: 'lb', reps: 10, completed_at: '2026-10-01T10:12:00.000000Z',
    },
    {
      workout_exercise_key: 'current-slot-b', exercise_key: 'current-exercise', position: 2,
      prescription: {
        name: 'Captured skipped movement', instructions: 'Old instructions', stopping_guidance: 'Stop',
        warmup_guidance: { steps: [], note: 'Old warmup' }, video_key: null,
        reps_min: 8, reps_max: 12, rep_scope: 'reps', rest_seconds: 120,
      },
      weight: null, unit: 'lb', reps: null, completed_at: null,
    },
  ]);

  const second = await handleHistoryRequest(request(await token(), `?limit=2&cursor=${firstPage.next_cursor}`), env, database);
  assert.equal(second.status, 200);
  const secondPage = await second.json() as {
    sessions: Record<string, unknown>[]; next_cursor: string | null; has_more: boolean;
  };
  assert.equal(secondPage.has_more, false);
  assert.equal(secondPage.next_cursor, null);
  assert.deepEqual(secondPage.sessions.map(item => item.session_id), [
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  ]);
});

test('history rejects invalid, oversized, and foreign-account continuations', async () => {
  const bearer = await token();
  assert.equal((await handleHistoryRequest(request(bearer, '?limit=51'), env, database)).status, 400);
  assert.equal((await handleHistoryRequest(request(bearer, '?cursor=not-a-cursor'), env, database)).status, 400);
  assert.equal((await handleHistoryRequest(request(bearer, `?cursor=${foreignCursor()}`), env, database)).status, 400);
});

test('history never returns another account or active sessions', async () => {
  const response = await handleHistoryRequest(request(await token()), env, database);
  const page = await response.json() as { sessions: Record<string, unknown>[] };
  const ids = page.sessions.map(session => session.session_id);
  assert.ok(!ids.includes('dddddddd-dddd-4ddd-8ddd-dddddddddddd'));
  assert.ok(!ids.includes('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'));

  const other = await handleHistoryRequest(request(await token('other_history_user')), env, database);
  const otherPage = await other.json() as { sessions: Record<string, unknown>[] };
  assert.deepEqual(otherPage.sessions.map(session => session.session_id), [
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  ]);
});
