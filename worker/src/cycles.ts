import { authenticateClerkRequest, type ClerkConfiguration } from './authentication.ts';

export interface CycleDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

export async function handleCycleRequest(request: Request, env: ClerkConfiguration, database: CycleDatabase): Promise<Response> {
  const path = new URL(request.url).pathname;
  if (path !== '/v1/me/cycles' && path !== '/v1/cycles') return json({ error: { code: 'NOT_FOUND' } }, 404);
  if ((path === '/v1/me/cycles' && request.method !== 'GET') || (path === '/v1/cycles' && request.method !== 'POST')) {
    return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);
  }
  const auth = await authenticateClerkRequest(request, env);
  if ('response' in auth) return auth.response;
  try {
    if (path === '/v1/cycles') {
      const reader = request.body?.getReader();
      if (!reader) return json({ error: { code: 'INVALID_CYCLE' } }, 400);
      const chunks: Uint8Array[] = [];
      let size = 0;
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 65536) { await reader.cancel(); return json({ error: { code: 'INVALID_CYCLE' } }, 400); }
        chunks.push(value);
      }
      let body: unknown;
      try {
        const bytes = new Uint8Array(size); let offset = 0;
        for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
        body = JSON.parse(new TextDecoder().decode(bytes));
      } catch { return json({ error: { code: 'INVALID_CYCLE' } }, 400); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) return json({ error: { code: 'INVALID_CYCLE' } }, 400);
      const value = body as Record<string, unknown>;
      if (Object.keys(value).some(key => !['cycle_id', 'program_id', 'started_at', 'preferences'].includes(key))
        || typeof value.cycle_id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value.cycle_id)
        || typeof value.program_id !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/.test(value.program_id)
        || typeof value.started_at !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,3})?Z$/.test(value.started_at)
        || !Number.isFinite(Date.parse(value.started_at))) return json({ error: { code: 'INVALID_CYCLE' } }, 400);
      if (value.preferences !== undefined && (!Array.isArray(value.preferences) || value.preferences.length > 100 || value.preferences.some((item: unknown) => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) return true;
        const preference = item as Record<string, unknown>;
        const key = (v: unknown) => typeof v === 'string' && v.length <= 128 && /^[a-z0-9][a-z0-9_-]*$/.test(v);
        return Object.keys(preference).sort().join(',') !== 'exercise_id,note,rest_seconds,workout_exercise_id'
          || !key(preference.workout_exercise_id) || (preference.exercise_id !== null && !key(preference.exercise_id))
          || (preference.note !== null && (typeof preference.note !== 'string' || preference.note.length > 2000))
          || (preference.rest_seconds !== null && (!Number.isInteger(preference.rest_seconds) || Number(preference.rest_seconds) < 1 || Number(preference.rest_seconds) > 2147483647));
      }))) return json({ error: { code: 'INVALID_CYCLE' } }, 400);
      const [row] = await database.query('SELECT public.create_program_cycle($1, $2, $3::uuid, $4::timestamptz, $5::jsonb) AS result', [auth.subject, value.program_id, value.cycle_id, value.started_at, value.preferences === undefined ? 'null' : JSON.stringify(value.preferences)]);
      if (row?.result === 'created' || row?.result === 'acknowledged') return json({ cycle_id: value.cycle_id, result: row.result }, row.result === 'created' ? 201 : 200);
      if (row?.result === 'invalid') return json({ error: { code: 'INVALID_CYCLE' } }, 400);
      if (row?.result === 'forbidden') return json({ error: { code: 'FORBIDDEN' } }, 403);
      if (row?.result === 'unavailable') return json({ error: { code: 'PROGRAM_UNAVAILABLE' } }, 409);
      if (row?.result === 'conflict' || row?.result === 'setup_required') return json({ error: { code: 'CYCLE_CONFLICT' } }, 409);
      return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
    }
    const [row] = await database.query(`SELECT owner.active_user_program_id AS selected_cycle_id,
      COALESCE((SELECT json_agg(json_build_object('cycle_id', latest.id, 'program_id', latest.authoring_key,
        'started_at', to_char(latest.started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')) ORDER BY latest.authoring_key)
        FROM (SELECT DISTINCT ON (cycle.workout_program_id) cycle.id, cycle.started_at, program.authoring_key
          FROM public.user_programs cycle JOIN public.workout_programs program ON program.id = cycle.workout_program_id
          WHERE cycle.user_id = owner.id ORDER BY cycle.workout_program_id, cycle.started_at DESC, cycle.id DESC) latest), '[]'::json) AS cycles
      FROM public.users owner WHERE owner.clerk_user_id = $1`, [auth.subject]);
    if (!row) return json({ selected_cycle_id: null, cycles: [] });
    if (!Array.isArray(row.cycles) || (row.selected_cycle_id !== null && !row.cycles.some((cycle: { cycle_id: unknown }) => cycle.cycle_id === row.selected_cycle_id))) {
      return json({ error: { code: 'CYCLE_UNAVAILABLE' } }, 503);
    }
    return json({ selected_cycle_id: row.selected_cycle_id, cycles: row.cycles });
  } catch {
    console.error(JSON.stringify({ event: 'cycle_request_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
