import { verifyToken } from '@clerk/backend';
import { eraseAccountData, type AccountErasureDatabase } from './account-deletion';
import { getUser, type ClerkUserResult } from './clerk-users';

export interface SetupDatabase extends AccountErasureDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}
export interface SetupServices {
  getClerkUser(clerkUserId: string, secretKey: string): Promise<ClerkUserResult>;
}
const defaultServices: SetupServices = {
  getClerkUser: (clerkUserId, secretKey) => getUser(clerkUserId, secretKey),
};
export interface SetupConfiguration {
  CLERK_SECRET_KEY: string;
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}

export async function handleSetupRequest(
  request: Request, env: SetupConfiguration, database: SetupDatabase,
  services: SetupServices = defaultServices,
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

  // Provision the identity link before lookup, including for restored sessions.
  // Initial preferences match onboarding; only completed setup will select a cycle.
  // The unique Clerk ID makes retries/concurrent requests safe without changing saved data.
  // Stale-token guard: Clerk session tokens outlive account deletion by about a minute, so a
  // row this insert actually creates is confirmed against Clerk and erased if the user is gone.
  // This is the only place a users row may be created: PUT runs it before complete_onboarding, so
  // that function must never insert a user itself (a future migration must keep it that way).
  // Returns a rejection response, or null when the identity is confirmed or already existed.
  async function provisionUser(): Promise<Response | null> {
    const created = await database.query(`
      INSERT INTO users (clerk_user_id, preferred_unit, training_days)
      VALUES ($1, 'kg', 3)
      ON CONFLICT (clerk_user_id) DO NOTHING
      RETURNING id
    `, [subject]);
    if (created.length === 0) return null;
    const identity = await services.getClerkUser(subject, env.CLERK_SECRET_KEY);
    if (identity.status === 'success') return null;
    await eraseUnconfirmedRow();
    return identity.status === 'notFound'
      ? json({ error: { code: 'AUTH_REQUIRED' } }, 401)
      : json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }

  // The new row must not outlive a failed confirmation: later setups skip the Clerk check for
  // existing rows, so a stale token could revive a deleted account. Retry the erase once; if it
  // still fails, the error reaches the outer handler and the response is 503.
  async function eraseUnconfirmedRow(): Promise<void> {
    try {
      await eraseAccountData(database, subject);
    } catch {
      await eraseAccountData(database, subject);
    }
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
      if (!body || !['kg', 'lb'].includes(body.preferred_unit)
        || !Number.isInteger(body.training_days) || body.training_days < 2 || body.training_days > 5
        || typeof body.program_id !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/.test(body.program_id)
        || typeof body.cycle_id !== 'string'
        || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.cycle_id)
        || Object.keys(body).some(key => !['preferred_unit', 'training_days', 'program_id', 'cycle_id'].includes(key))) {
        return json({ error: { code: 'INVALID_SETUP' } }, 400);
      }
      const [program] = await database.query(`SELECT id FROM workout_programs
        WHERE authoring_key = $1`, [body.program_id]);
      if (!program || !Number.isInteger(program.id)) return json({ error: { code: 'PROGRAM_UNAVAILABLE' } }, 409);
      const rejected = await provisionUser();
      if (rejected) return rejected;
      const [completion] = await database.query(`SELECT public.complete_onboarding($1, $2::weight_unit,
        $3::integer, $4::integer, $5::uuid) AS accepted`,
      [subject, body.preferred_unit, String(body.training_days), String(program.id), body.cycle_id]);
      if (completion?.accepted === false) return json({ error: { code: 'PROGRAM_UNAVAILABLE' } }, 409);
      if (completion?.accepted !== true) return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
    }
    if (request.method === 'GET') {
      const rejected = await provisionUser();
      if (rejected) return rejected;
    }
    // A single statement gives a consistent snapshot and checks ownership of the active cycle.
    const [row] = await database.query(`
      SELECT u.preferred_unit, u.training_days, u.active_user_program_id,
             p.id AS cycle_id, p.workout_program_id, program.authoring_key AS program_id,
             EXISTS (SELECT 1 FROM user_programs owned WHERE owned.user_id = u.id) AS has_cycles
      FROM users u
      LEFT JOIN user_programs p ON p.id = u.active_user_program_id AND p.user_id = u.id
      LEFT JOIN workout_programs program ON program.id = p.workout_program_id
      WHERE u.clerk_user_id = $1
    `, [subject]);
    if (!row || (row.active_user_program_id === null && row.has_cycles === false)) {
      return json({ setup: null });
    }
    const programID = row.program_id;
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
