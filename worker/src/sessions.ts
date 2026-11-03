import { verifyToken } from '@clerk/backend';

export interface SessionDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}

export interface SessionConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
}

type SessionPrescription = {
  name: string;
  instructions: string;
  stopping_guidance: string;
  warmup_guidance: { steps: unknown[]; note: string };
  video_key: string | null;
  reps_min: number;
  reps_max: number;
  rep_scope: 'reps' | 'each_leg' | 'each_side';
  rest_seconds: number | null;
};

type SessionSet = {
  workout_exercise_key: string;
  exercise_key: string;
  position: number;
  prescription: SessionPrescription;
  weight: number | null;
  unit: 'kg' | 'lb';
  reps: number | null;
  completed_at: string | null;
};

type CompletedSession = {
  session_id: string;
  cycle_id: string;
  program_key: string;
  workout_key: string;
  week_number: number;
  workout_name: string;
  started_at: string;
  completed_at: string;
  note: string | null;
  day_number?: number | null;
  sets: SessionSet[];
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const KEY = /^[a-z0-9][a-z0-9_-]*$/;
const ISO_TIMESTAMP = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/i;
const POSTGRES_INT_MAX = 2_147_483_647;
const MAX_BODY_BYTES = 1_048_576;

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

async function readBody(request: Request): Promise<unknown | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY_BYTES) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(new TextDecoder().decode(bytes)); } catch { return null; }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function onlyKeys(value: Record<string, unknown>, expected: string[]): boolean {
  return Object.keys(value).every(key => expected.includes(key));
}

function validText(value: unknown, maximum: number, allowEmpty = false): value is string {
  return typeof value === 'string' && value.length <= maximum
    && (allowEmpty || value.trim().length > 0);
}

function validDate(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const parts = ISO_TIMESTAMP.exec(value);
  if (!parts) return false;
  const year = Number(parts[1]);
  const month = Number(parts[2]);
  const day = Number(parts[3]);
  const hour = Number(parts[4]);
  const minute = Number(parts[5]);
  const second = Number(parts[6]);
  const calendar = new Date(0);
  calendar.setUTCFullYear(year, month - 1, day);
  calendar.setUTCHours(hour, minute, second, 0);
  return calendar.getUTCFullYear() === year
    && calendar.getUTCMonth() === month - 1
    && calendar.getUTCDate() === day
    && calendar.getUTCHours() === hour
    && calendar.getUTCMinutes() === minute
    && calendar.getUTCSeconds() === second
    && Number.isFinite(Date.parse(value));
}

function positiveInt32(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value)
    && value > 0 && value <= POSTGRES_INT_MAX;
}

function validPrescription(value: unknown): value is SessionPrescription {
  if (!isObject(value) || !onlyKeys(value, [
    'name', 'instructions', 'stopping_guidance', 'warmup_guidance', 'video_key',
    'reps_min', 'reps_max', 'rep_scope', 'rest_seconds',
  ])) return false;
  const warmup = value.warmup_guidance;
  return validText(value.name, 300)
    && validText(value.instructions, 4_000)
    && validText(value.stopping_guidance, 2_000)
    && isObject(warmup) && onlyKeys(warmup, ['steps', 'note'])
    && Array.isArray(warmup.steps) && warmup.steps.length <= 20
    && validText(warmup.note, 2_000, true)
    && (value.video_key === null || validText(value.video_key, 500))
    && positiveInt32(value.reps_min) && positiveInt32(value.reps_max)
    && value.reps_max >= value.reps_min
    && ['reps', 'each_leg', 'each_side'].includes(String(value.rep_scope))
    && (value.rest_seconds === null || (Number.isInteger(value.rest_seconds)
      && Number(value.rest_seconds) > 0 && Number(value.rest_seconds) <= 86_400));
}

function validSession(value: unknown): value is CompletedSession {
  if (!isObject(value) || !onlyKeys(value, [
    'session_id', 'cycle_id', 'program_key', 'workout_key', 'week_number', 'workout_name',
    'started_at', 'completed_at', 'note', 'day_number', 'sets',
  ])) return false;
  if (typeof value.session_id !== 'string' || !UUID.test(value.session_id)
    || typeof value.cycle_id !== 'string' || !UUID.test(value.cycle_id)
    || !validText(value.program_key, 100) || !KEY.test(value.program_key)
    || !validText(value.workout_key, 100) || !KEY.test(value.workout_key)
    || !positiveInt32(value.week_number)
    || !validText(value.workout_name, 300)
    || !validDate(value.started_at) || !validDate(value.completed_at)
    || Date.parse(value.completed_at) < Date.parse(value.started_at)
    || (value.day_number !== undefined && value.day_number !== null
      && (!positiveInt32(value.day_number) || value.day_number > 100))
    || !(value.note === null || validText(value.note, 4_000, true))
    || !Array.isArray(value.sets) || value.sets.length < 1 || value.sets.length > 100) return false;

  const startedAt = Date.parse(value.started_at);
  const finishedAt = Date.parse(value.completed_at);
  const slotKeys = new Set<string>();
  let hasCompletedSet = false;
  for (const [index, rawSet] of value.sets.entries()) {
    if (!isObject(rawSet) || !onlyKeys(rawSet, [
      'workout_exercise_key', 'exercise_key', 'position', 'prescription',
      'weight', 'unit', 'reps', 'completed_at',
    ])) return false;
    if (!validText(rawSet.workout_exercise_key, 100) || !KEY.test(rawSet.workout_exercise_key)
      || !validText(rawSet.exercise_key, 100) || !KEY.test(rawSet.exercise_key)
      || !positiveInt32(rawSet.position) || rawSet.position !== index + 1
      || slotKeys.has(rawSet.workout_exercise_key)
      || !validPrescription(rawSet.prescription)
      || !['kg', 'lb'].includes(String(rawSet.unit))) return false;
    slotKeys.add(rawSet.workout_exercise_key);

    if (rawSet.completed_at === null) {
      if (rawSet.weight !== null || rawSet.reps !== null) return false;
      continue;
    }
    if (!validDate(rawSet.completed_at)) return false;
    const setCompletedAt = Date.parse(rawSet.completed_at);
    if (setCompletedAt < startedAt || setCompletedAt > finishedAt
      || typeof rawSet.weight !== 'number' || !Number.isFinite(rawSet.weight)
      || rawSet.weight < 0 || rawSet.weight > 9_999_999.999
      || Math.abs(rawSet.weight * 1_000 - Math.round(rawSet.weight * 1_000)) > 0.000_001
      || !positiveInt32(rawSet.reps)) return false;
    hasCompletedSet = true;
  }
  return hasCompletedSet;
}

export async function handleCompletedSessionRequest(
  request: Request, env: SessionConfiguration, database: SessionDatabase,
): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname !== '/v1/sessions/completed') return json({ error: { code: 'NOT_FOUND' } }, 404);
  if (request.method !== 'POST') return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);
  const bearer = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!bearer) return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
  if (!env.CLERK_JWT_KEY || !env.CLERK_ISSUER || !env.CLERK_AUTHORIZED_PARTIES) {
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }

  let subject: string;
  try {
    const claims = await verifyToken(bearer, { jwtKey: env.CLERK_JWT_KEY, clockSkewInMs: 0 });
    const parties = env.CLERK_AUTHORIZED_PARTIES.split(',').map(origin => origin.trim());
    if (claims.iss !== env.CLERK_ISSUER
      || (claims.azp !== undefined && !parties.includes(claims.azp))
      || !claims.sub || !claims.sid || claims.sts === 'pending') {
      return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
    }
    subject = claims.sub;
  } catch {
    return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
  }

  const body = await readBody(request);
  if (!validSession(body)) return json({ error: { code: 'INVALID_SESSION' } }, 400);
  try {
    const [row] = await database.query(
      'SELECT public.save_completed_session_with_day($1::text, $2::jsonb) AS result',
      [subject, JSON.stringify(body)],
    );
    const result = row?.result;
    if (result === 'created') return json({ session_id: body.session_id, result }, 201);
    if (result === 'acknowledged') return json({ session_id: body.session_id, result }, 200);
    if (result === 'session_conflict') return json({ error: { code: 'SESSION_CONFLICT' } }, 409);
    if (result === 'cycle_forbidden') return json({ error: { code: 'FORBIDDEN' } }, 403);
    if (result === 'invalid_session') return json({ error: { code: 'INVALID_SESSION' } }, 422);
    console.error(JSON.stringify({ event: 'completed_session_save_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  } catch {
    console.error(JSON.stringify({ event: 'completed_session_save_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
