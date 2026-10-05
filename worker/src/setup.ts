import { verifyToken } from '@clerk/backend';

export interface SetupDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}
export interface SetupConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
  PROGRAM_CATALOG_MAP: string;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

export async function handleSetupRequest(
  request: Request, env: SetupConfiguration, database: SetupDatabase,
): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname !== '/v1/me/setup') return json({ error: { code: 'NOT_FOUND' } }, 404);
  if (!['GET', 'PUT'].includes(request.method)) return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);
  const bearer = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!bearer) return json({ error: { code: 'AUTH_REQUIRED' } }, 401);
  if (!env.CLERK_JWT_KEY || !env.CLERK_ISSUER || !env.CLERK_AUTHORIZED_PARTIES) {
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }

  let subject: string;
  try {
    const claims = await verifyToken(bearer, {
      jwtKey: env.CLERK_JWT_KEY,
      clockSkewInMs: 0,
    });
    // Native Clerk session tokens may omit azp; browser tokens must match the allowlist.
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
    if (request.method === 'PUT') {
      // Bound the body even when Content-Length is missing or untrusted.
      const reader = request.body?.getReader();
      if (!reader) return json({ error: { code: 'INVALID_SETUP' } }, 400);
      const chunks: Uint8Array[] = [];
      let size = 0;
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 2048) {
          await reader.cancel();
          return json({ error: { code: 'INVALID_SETUP' } }, 400);
        }
        chunks.push(value);
      }
      let body;
      try {
        const bytes = new Uint8Array(size);
        let offset = 0;
        for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
        body = JSON.parse(new TextDecoder().decode(bytes));
      } catch { return json({ error: { code: 'INVALID_SETUP' } }, 400); }
      const catalog: Record<string, unknown> = JSON.parse(env.PROGRAM_CATALOG_MAP);
      const program = Object.entries(catalog).find(([id, name]) =>
        name === body?.program_id && /^[1-9][0-9]*$/.test(id))?.[0];
      if (!body || !['kg', 'lb'].includes(body.preferred_unit)
        || !Number.isInteger(body.training_days) || body.training_days < 2 || body.training_days > 5
        || !program || typeof body.cycle_id !== 'string'
        || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.cycle_id)
        || Object.keys(body).some(key => !['preferred_unit', 'training_days', 'program_id', 'cycle_id'].includes(key))) {
        return json({ error: { code: 'INVALID_SETUP' } }, 400);
      }
      await database.query(`SELECT public.complete_onboarding($1, $2::weight_unit,
        $3::integer, $4::integer, $5::uuid)`,
      [subject, body.preferred_unit, String(body.training_days), program, body.cycle_id]);
    }
    // A single statement gives a consistent snapshot and checks ownership of the active cycle.
    const [row] = await database.query(`
      SELECT u.preferred_unit, u.training_days, u.active_user_program_id,
             p.id AS cycle_id, p.workout_program_id,
             EXISTS (SELECT 1 FROM user_programs owned WHERE owned.user_id = u.id) AS has_cycles
      FROM users u
      LEFT JOIN user_programs p ON p.id = u.active_user_program_id AND p.user_id = u.id
      WHERE u.clerk_user_id = $1
    `, [subject]);
    if (!row || (row.active_user_program_id === null && row.has_cycles === false)) {
      return json({ setup: null });
    }
    const catalog: Record<string, unknown> = JSON.parse(env.PROGRAM_CATALOG_MAP);
    const programID = catalog[String(row.workout_program_id)];
    if (!row.cycle_id || typeof programID !== 'string' || !programID
      || !['kg', 'lb'].includes(String(row.preferred_unit))
      || typeof row.training_days !== 'number' || row.training_days < 2 || row.training_days > 5) {
      return json({ error: { code: 'SETUP_UNAVAILABLE' } }, 503);
    }
    return json({ setup: {
      preferred_unit: row.preferred_unit, training_days: row.training_days,
      program_id: programID, cycle_id: row.cycle_id,
    } });
  } catch {
    console.error(JSON.stringify({ event: 'setup_lookup_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
