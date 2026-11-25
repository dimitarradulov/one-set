import { authenticateClerkRequest, type ClerkConfiguration } from './authentication';

export interface PreferencesDatabase {
  query(sql: string, params: string[]): Promise<Record<string, unknown>[]>;
}

const MAX_BODY_BYTES = 2048;
const FIELDS = ['preferred_unit', 'training_days'];

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store' } });
}
const invalid = () => json({ error: { code: 'INVALID_SETTINGS' } }, 400);

// Reads at most MAX_BODY_BYTES even when Content-Length is missing or untrusted.
async function readBoundedBody(request: Request): Promise<unknown | undefined> {
  const reader = request.body?.getReader();
  if (!reader) return undefined;
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BODY_BYTES) {
      await reader.cancel();
      return undefined;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(new TextDecoder().decode(bytes)); } catch { return undefined; }
}

// PATCH /v1/me: saves the preferred unit and training frequency of the verified account.
// The latest saved values win; there is no revision. Ownership comes only from the verified subject.
export async function handlePreferencesRequest(
  request: Request, env: ClerkConfiguration, database: PreferencesDatabase,
): Promise<Response> {
  if (new URL(request.url).pathname !== '/v1/me') return json({ error: { code: 'NOT_FOUND' } }, 404);
  if (request.method !== 'PATCH') return json({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);
  const authentication = await authenticateClerkRequest(request, env);
  if ('response' in authentication) return authentication.response;

  const body = await readBoundedBody(request) as Record<string, unknown> | null | undefined;
  if (!body || typeof body !== 'object' || Array.isArray(body)
    || Object.keys(body).length !== FIELDS.length
    || Object.keys(body).some(key => !FIELDS.includes(key))
    || (body.preferred_unit !== 'kg' && body.preferred_unit !== 'lb')
    || !Number.isInteger(body.training_days)
    || (body.training_days as number) < 2 || (body.training_days as number) > 5) {
    return invalid();
  }

  try {
    // One statement updates only an account that completed setup, so a missing or unfinished
    // account is never created or changed here.
    const rows = await database.query(`
      UPDATE users SET preferred_unit = $2::weight_unit, training_days = $3::integer
      WHERE clerk_user_id = $1
        AND (active_user_program_id IS NOT NULL
             OR EXISTS (SELECT 1 FROM user_programs owned WHERE owned.user_id = users.id))
      RETURNING preferred_unit, training_days
    `, [authentication.subject, body.preferred_unit, String(body.training_days)]);
    const [saved] = rows;
    if (!saved) return json({ error: { code: 'SETUP_REQUIRED' } }, 409);
    return json({ preferred_unit: saved.preferred_unit, training_days: saved.training_days });
  } catch {
    console.error(JSON.stringify({ event: 'preferences_update_failed' }));
    return json({ error: { code: 'TEMPORARY_FAILURE' } }, 503);
  }
}
