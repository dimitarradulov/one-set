import { verifyToken } from '@clerk/backend';

export interface ProgressDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}
export interface ProgressConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

export async function handleProgressRequest(
  request: Request, env: ProgressConfiguration, database: ProgressDatabase,
): Promise<Response> {
  if (new URL(request.url).pathname !== '/v1/me/progress') return json({ error: { code: 'NOT_FOUND' } }, 404);
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
    const [cycle] = await database.query(`
      SELECT cycle.id AS cycle_id, cycle.current_training_week,
             program.authoring_key AS program_id,
             coalesce((
               SELECT jsonb_agg(jsonb_build_object(
                 'week_number', marks.week_number, 'workout_id', workout.authoring_key
               ) ORDER BY marks.week_number, workout.authoring_key)
               FROM completed_workouts AS marks
               JOIN workouts AS workout ON workout.id = marks.workout_id
               WHERE marks.user_program_id = cycle.id
             ), '[]'::jsonb) AS completed_occurrences,
             coalesce((
               SELECT jsonb_agg(jsonb_build_object(
                 'workout_id', workout.authoring_key,
                 'starts_week', period.starts_week, 'ends_week', period.ends_week
               ) ORDER BY period.starts_week, workout.authoring_key)
               FROM user_program_workout_periods AS period
               JOIN workouts AS workout ON workout.id = period.workout_id
               WHERE period.user_program_id = cycle.id
             ), '[]'::jsonb) AS workout_periods,
             coalesce((
               SELECT jsonb_agg(workout.authoring_key ORDER BY required.workout_position)
               FROM required_workouts_for_cycle_week(cycle.id, cycle.current_training_week) AS required
               JOIN workouts AS workout ON workout.id = required.workout_id
             ), '[]'::jsonb) AS required_workouts
      FROM users AS owner
      JOIN user_programs AS cycle
        ON cycle.id = owner.active_user_program_id AND cycle.user_id = owner.id
      JOIN workout_programs AS program ON program.id = cycle.workout_program_id
      WHERE owner.clerk_user_id = $1
    `, [subject]);
    if (!cycle) return json({ progress: null });
    if (typeof cycle.cycle_id !== 'string' || typeof cycle.program_id !== 'string'
      || typeof cycle.current_training_week !== 'number' || cycle.current_training_week < 1) {
      return json({ error: { code: 'PROGRESS_UNAVAILABLE' } }, 503);
    }

    const completed = cycle.completed_occurrences as unknown;
    const periods = cycle.workout_periods as unknown;
    const required = cycle.required_workouts as unknown;
    if (!Array.isArray(completed) || !Array.isArray(periods) || !Array.isArray(required)
      || completed.some(row => !row || typeof row.workout_id !== 'string' || !Number.isInteger(row.week_number))
      || periods.some(row => !row || typeof row.workout_id !== 'string' || !Number.isInteger(row.starts_week))
      || required.some(workoutID => typeof workoutID !== 'string')) {
      return json({ error: { code: 'PROGRESS_UNAVAILABLE' } }, 503);
    }
    return json({ progress: {
      cycle_id: cycle.cycle_id,
      program_id: cycle.program_id,
      current_training_week: cycle.current_training_week,
      completed_occurrences: completed,
      workout_periods: periods,
      required_workouts: required,
    } });
  } catch {
    console.error(JSON.stringify({ event: 'progress_lookup_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
