import { verifyToken } from '@clerk/backend';

export interface HistoryDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}

export interface HistoryConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
}

interface HistoryCursor {
  version: 1;
  owner: string;
  startedAt: string;
  sessionID: string;
}

interface SessionKey {
  session_id: string;
  started_at: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/i;
const DEFAULT_PAGE_SIZE = 25;
const MAX_PAGE_SIZE = 50;
const MAX_CURSOR_LENGTH = 512;

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

function encodeCursor(cursor: HistoryCursor): string {
  const bytes = new TextEncoder().encode(JSON.stringify(cursor));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/u, '');
}

function decodeCursor(value: string): HistoryCursor | null {
  if (value.length === 0 || value.length > MAX_CURSOR_LENGTH || !/^[A-Za-z0-9_-]+$/u.test(value)) return null;
  try {
    const base64 = value.replaceAll('-', '+').replaceAll('_', '/');
    const padded = base64 + '='.repeat((4 - base64.length % 4) % 4);
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, character => character.charCodeAt(0));
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Record<string, unknown>;
    if (parsed.version !== 1 || typeof parsed.owner !== 'string' || parsed.owner.length === 0
      || typeof parsed.startedAt !== 'string' || !ISO_TIMESTAMP.test(parsed.startedAt)
      || !Number.isFinite(Date.parse(parsed.startedAt))
      || typeof parsed.sessionID !== 'string' || !UUID.test(parsed.sessionID)) return null;
    return {
      version: 1,
      owner: parsed.owner,
      startedAt: parsed.startedAt,
      sessionID: parsed.sessionID,
    };
  } catch {
    return null;
  }
}

function rowsFromJSON(value: unknown): unknown[] | null {
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string') return null;
  try {
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function validSessionRow(row: Record<string, unknown>): boolean {
  return typeof row.session_id === 'string' && UUID.test(row.session_id)
    && typeof row.cycle_id === 'string' && UUID.test(row.cycle_id)
    && typeof row.program_key === 'string' && typeof row.program_name === 'string'
    && typeof row.workout_key === 'string' && Number.isInteger(row.week_number)
    && (row.day_number === null || Number.isInteger(row.day_number))
    && typeof row.workout_name === 'string' && typeof row.started_at === 'string'
    && typeof row.completed_at === 'string'
    && (row.note === null || typeof row.note === 'string')
    && rowsFromJSON(row.sets) !== null;
}

export async function handleHistoryRequest(
  request: Request, env: HistoryConfiguration, database: HistoryDatabase,
): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname !== '/v1/sessions') return json({ error: { code: 'NOT_FOUND' } }, 404);
  if (request.method !== 'GET') return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);

  const bearer = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!bearer) return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
  if (!env.CLERK_JWT_KEY || !env.CLERK_ISSUER || !env.CLERK_AUTHORIZED_PARTIES) {
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }

  let owner: string;
  try {
    const claims = await verifyToken(bearer, { jwtKey: env.CLERK_JWT_KEY, clockSkewInMs: 0 });
    const parties = env.CLERK_AUTHORIZED_PARTIES.split(',').map(origin => origin.trim());
    if (claims.iss !== env.CLERK_ISSUER
      || (claims.azp !== undefined && !parties.includes(claims.azp))
      || !claims.sub || !claims.sid || claims.sts === 'pending') {
      return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
    }
    owner = claims.sub;
  } catch {
    return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
  }

  const sizeParameter = url.searchParams.get('limit');
  const pageSize = sizeParameter === null ? DEFAULT_PAGE_SIZE : Number(sizeParameter);
  if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > MAX_PAGE_SIZE) {
    return json({ error: { code: 'INVALID_PAGE_SIZE' } }, 400);
  }

  const cursorParameter = url.searchParams.get('cursor');
  const cursor = cursorParameter === null ? null : decodeCursor(cursorParameter);
  if (cursorParameter !== null && !cursor) {
    return json({ error: { code: 'INVALID_CURSOR' } }, 400);
  }
  if (cursor && cursor.owner !== owner) {
    return json({ error: { code: 'INVALID_CURSOR' } }, 400);
  }

  const cursorPredicate = cursor
    ? 'AND (session.started_at, session.id) < ($2::timestamptz, $3::uuid)'
    : '';
  const parameters = cursor
    ? [owner, cursor.startedAt, cursor.sessionID, String(pageSize + 1)]
    : [owner, String(pageSize + 1)];
  const limitParameter = cursor ? '$4' : '$2';
  try {
    const fetched = await database.query(`
      WITH page AS (
        SELECT session.id AS session_id,
               cycle.id AS cycle_id,
               program.authoring_key AS program_key,
               program.name AS program_name,
               workout.authoring_key AS workout_key,
               session.week_number,
               session.day_number,
               session.workout_name,
               to_char(session.started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS started_at,
               to_char(session.completed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS completed_at,
               session.note
        FROM public.users AS account
        JOIN public.user_programs AS cycle ON cycle.user_id = account.id
        JOIN public.workout_sessions AS session ON session.user_program_id = cycle.id
        JOIN public.workout_programs AS program ON program.id = cycle.workout_program_id
        JOIN public.workouts AS workout ON workout.id = session.workout_id
        WHERE account.clerk_user_id = $1
          AND session.completed_at IS NOT NULL
          ${cursorPredicate}
        ORDER BY session.started_at DESC, session.id DESC
        LIMIT ${limitParameter}::integer
      )
      SELECT page.session_id::text,
             page.cycle_id::text,
             page.program_key,
             page.program_name,
             page.workout_key,
             page.week_number,
             page.day_number,
             page.workout_name,
             page.started_at,
             page.completed_at,
             page.note,
             coalesce((
               SELECT jsonb_agg(jsonb_build_object(
                 'workout_exercise_key', slot.authoring_key,
                 'exercise_key', exercise.authoring_key,
                 'position', result.position,
                 'prescription', result.prescription,
                 'weight', result.weight::text,
                 'unit', result.unit,
                 'reps', result.reps,
                 'completed_at', CASE WHEN result.completed_at IS NULL THEN NULL
                   ELSE to_char(result.completed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END
               ) ORDER BY result.position)
               FROM public.workout_session_sets AS result
               JOIN public.workout_exercises AS slot ON slot.id = result.workout_exercise_id
               JOIN public.exercises AS exercise ON exercise.id = result.exercise_id
               WHERE result.workout_session_id = page.session_id
             ), '[]'::jsonb) AS sets
      FROM page
      ORDER BY page.started_at DESC, page.session_id DESC
    `, parameters);

    if (fetched.some(row => !validSessionRow(row))) {
      console.error(JSON.stringify({ event: 'history_page_invalid_data' }));
      return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
    }
    const hasMore = fetched.length > pageSize;
    const sessions = hasMore ? fetched.slice(0, pageSize) : fetched;
    const last = sessions.at(-1) as SessionKey | undefined;
    const nextCursor = hasMore && last
      ? encodeCursor({ version: 1, owner, startedAt: last.started_at, sessionID: last.session_id })
      : null;
    return json({ sessions, next_cursor: nextCursor, has_more: hasMore });
  } catch {
    console.error(JSON.stringify({ event: 'history_page_read_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
