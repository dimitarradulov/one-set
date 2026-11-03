import { verifyToken } from '@clerk/backend';

export interface PreviousPerformanceDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}

export interface PreviousPerformanceConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

export async function handlePreviousPerformanceRequest(
  request: Request, env: PreviousPerformanceConfiguration, database: PreviousPerformanceDatabase,
): Promise<Response> {
  if (new URL(request.url).pathname !== '/v1/me/previous-performance') {
    return json({ error: { code: 'NOT_FOUND' } }, 404);
  }
  if (request.method !== 'GET') return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);
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

  try {
    const results = await database.query(`
      WITH owned_results AS (
        SELECT exercise.authoring_key AS exercise_key,
               program.authoring_key AS program_key,
               workout.authoring_key AS workout_key,
               slot.authoring_key AS slot_key,
               session.week_number,
               session.workout_name,
               set_row.weight::text AS weight,
               set_row.unit::text AS unit,
               set_row.reps,
               set_row.completed_at,
               session.completed_at AS session_completed_at,
               session.id AS session_id,
               row_number() OVER (
                 PARTITION BY exercise.id, program.id, workout.id, slot.id
                 ORDER BY set_row.completed_at DESC, session.completed_at DESC,
                          session.id DESC, set_row.position ASC
               ) AS workout_rank
        FROM users AS owner
        JOIN user_programs AS cycle ON cycle.user_id = owner.id
        JOIN workout_programs AS program ON program.id = cycle.workout_program_id
        JOIN workout_sessions AS session ON session.user_program_id = cycle.id
        JOIN workout_session_sets AS set_row ON set_row.workout_session_id = session.id
        JOIN exercises AS exercise ON exercise.id = set_row.exercise_id
        JOIN workouts AS workout ON workout.id = session.workout_id
        JOIN workout_exercises AS slot ON slot.id = set_row.workout_exercise_id
        WHERE owner.clerk_user_id = $1
          AND session.completed_at IS NOT NULL
          AND set_row.completed_at IS NOT NULL
          AND set_row.weight IS NOT NULL
          AND set_row.reps IS NOT NULL
      )
      SELECT exercise_key, program_key, workout_key, slot_key, week_number,
             workout_name, weight, unit, reps,
             to_char(completed_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS completed_at,
             session_id::text AS session_id
      FROM owned_results
      WHERE workout_rank = 1
      ORDER BY exercise_key, completed_at DESC,
               program_key, workout_key, session_id
    `, [subject]);
    return json({ results });
  } catch {
    console.error(JSON.stringify({ event: 'previous_performance_lookup_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
