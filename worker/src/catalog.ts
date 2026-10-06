import { verifyToken } from '@clerk/backend';
import { diffCatalog, validateCatalogSource, type CatalogSource } from './catalog-validation';

export interface CatalogDatabase {
  query(sql: string, params?: string[]): Promise<Record<string, unknown>[]>;
  transaction(sql: string, params?: string[]): Promise<Record<string, unknown>[]>;
}

export interface CatalogConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
  CATALOG_PUBLISH_TOKEN: string;
}

interface PublicationState {
  publication_id: string | null;
  source_fingerprint: string | null;
  source_document: unknown;
}

function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'private, no-store', ...headers },
  });
}

function error(code: string, status: number): Response {
  return json({ error: { code } }, status);
}

async function fingerprint(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
}

async function sameSecret(candidate: string | undefined, expected: string): Promise<boolean> {
  const [candidateHash, expectedHash] = await Promise.all([
    fingerprint(candidate ?? ''), fingerprint(expected),
  ]);
  let difference = 0;
  for (let index = 0; index < candidateHash.length; index++) {
    difference |= candidateHash.charCodeAt(index) ^ expectedHash.charCodeAt(index);
  }
  return difference === 0 && candidate !== undefined;
}

async function readBody(request: Request): Promise<unknown | Response> {
  const reader = request.body?.getReader();
  if (!reader) return error('INVALID_CATALOG', 400);
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 1_048_576) {
      await reader.cancel();
      return error('INVALID_CATALOG', 413);
    }
    chunks.push(value);
  }
  try {
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
  } catch {
    return error('INVALID_CATALOG', 400);
  }
}

async function readState(database: CatalogDatabase): Promise<PublicationState | undefined> {
  const [row] = await database.query(`SELECT publication_id, source_fingerprint, source_document
    FROM public.catalog_state WHERE singleton = true`);
  if (!row) return undefined;
  return {
    publication_id: typeof row.publication_id === 'string' ? row.publication_id : null,
    source_fingerprint: typeof row.source_fingerprint === 'string' ? row.source_fingerprint : null,
    source_document: row.source_document ?? null,
  };
}

function checkedPrevious(value: unknown): CatalogSource | undefined {
  if (value === null || value === undefined) return undefined;
  const { catalog, errors } = validateCatalogSource(value);
  return errors.length === 0 ? catalog : undefined;
}

async function clerkAuthenticated(request: Request, env: CatalogConfiguration): Promise<boolean> {
  const bearer = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!bearer || !env.CLERK_JWT_KEY || !env.CLERK_ISSUER || !env.CLERK_AUTHORIZED_PARTIES) return false;
  try {
    const claims = await verifyToken(bearer, { jwtKey: env.CLERK_JWT_KEY, clockSkewInMs: 0 });
    const parties = env.CLERK_AUTHORIZED_PARTIES.split(',').map(origin => origin.trim());
    return claims.iss === env.CLERK_ISSUER
      && (claims.azp === undefined || parties.includes(claims.azp))
      && Boolean(claims.sub && claims.sid && claims.sts !== 'pending');
  } catch {
    return false;
  }
}

function sourceFromBody(value: unknown): JsonObject | undefined {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return undefined;
  return value as JsonObject;
}

type JsonObject = Record<string, unknown>;

async function reviewCatalog(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
): Promise<Response> {
  if (request.method !== 'POST') return error('METHOD_NOT_ALLOWED', 405);
  const secret = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!env.CATALOG_PUBLISH_TOKEN || !(await sameSecret(secret, env.CATALOG_PUBLISH_TOKEN))) {
    return error('FORBIDDEN', 403);
  }
  const bodyValue = await readBody(request);
  if (bodyValue instanceof Response) return bodyValue;
  const body = sourceFromBody(bodyValue);
  const source = body?.source;
  const sourceFingerprint = body?.source_fingerprint;
  if (source === undefined || typeof sourceFingerprint !== 'string' || !/^[a-f0-9]{64}$/.test(sourceFingerprint)) {
    return error('INVALID_CATALOG', 400);
  }
  const normalizedSource = JSON.stringify(source);
  if (await fingerprint(normalizedSource) !== sourceFingerprint) return error('INVALID_CATALOG', 400);

  const state = await readState(database);
  if (!state) return error('CATALOG_UNAVAILABLE', 503);
  const previous = checkedPrevious(state.source_document);
  if (state.source_document && !previous) return error('CATALOG_UNAVAILABLE', 503);
  const { catalog, errors } = validateCatalogSource(source, previous);
  if (!catalog || errors.length > 0) return json({ error: { code: 'INVALID_CATALOG', details: errors } }, 422);

  const backendFingerprint = state.source_fingerprint ?? 'empty';
  const previewID = await fingerprint(`${backendFingerprint}\n${sourceFingerprint}`);
  const changes = diffCatalog(previous, catalog);
  return json({
    preview_id: previewID,
    backend_fingerprint: backendFingerprint,
    source_fingerprint: sourceFingerprint,
    changes: changes.changes,
    affected_programs: changes.affectedPrograms,
  });
}

async function publishCatalog(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
): Promise<Response> {
  if (request.method !== 'POST') return error('METHOD_NOT_ALLOWED', 405);
  const secret = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!env.CATALOG_PUBLISH_TOKEN || !(await sameSecret(secret, env.CATALOG_PUBLISH_TOKEN))) {
    return error('FORBIDDEN', 403);
  }
  const bodyValue = await readBody(request);
  if (bodyValue instanceof Response) return bodyValue;
  const body = sourceFromBody(bodyValue);
  const source = body?.source;
  const sourceFingerprint = body?.source_fingerprint;
  const backendFingerprint = body?.backend_fingerprint;
  const previewID = body?.preview_id;
  if (source === undefined || typeof sourceFingerprint !== 'string' || !/^[a-f0-9]{64}$/.test(sourceFingerprint)
      || typeof backendFingerprint !== 'string' || typeof previewID !== 'string') {
    return error('INVALID_CATALOG', 400);
  }
  const normalizedSource = JSON.stringify(source);
  if (await fingerprint(normalizedSource) !== sourceFingerprint
      || await fingerprint(`${backendFingerprint}\n${sourceFingerprint}`) !== previewID) {
    return error('STALE_PREVIEW', 409);
  }

  const state = await readState(database);
  if (!state) return error('CATALOG_UNAVAILABLE', 503);
  const previous = checkedPrevious(state.source_document);
  if (state.source_document && !previous) return error('CATALOG_UNAVAILABLE', 503);
  let wasPublished = false;
  try {
    const [publication] = await database.query(`SELECT source_fingerprint FROM public.catalog_publications WHERE id = $1`, [previewID]);
    if (publication && publication.source_fingerprint !== sourceFingerprint) return error('STALE_PREVIEW', 409);
    wasPublished = publication !== undefined;
  } catch {
    return error('CATALOG_UNAVAILABLE', 503);
  }
  const isSuccessfulRetry = wasPublished;
  if (!isSuccessfulRetry && (state.source_fingerprint ?? 'empty') !== backendFingerprint) {
    return error('STALE_PREVIEW', 409);
  }
  const { catalog, errors } = validateCatalogSource(source, isSuccessfulRetry ? undefined : previous);
  if (!catalog || errors.length > 0) return json({ error: { code: 'INVALID_CATALOG', details: errors } }, 422);

  try {
    const [row] = await database.transaction(`SELECT public.publish_catalog(
      $1, $2, $3, $4::jsonb
    ) AS publication_id`, [backendFingerprint, previewID, sourceFingerprint, JSON.stringify(catalog)]);
    if (!row || typeof row.publication_id !== 'string') return error('TEMPORARY_FAILURE', 503);
    return json({ publication_id: row.publication_id });
  } catch (caught) {
    const message = caught instanceof Error ? caught.message : String(caught);
    if (message.includes('STALE_PREVIEW')) return error('STALE_PREVIEW', 409);
    if (message.includes('SLOT_IDENTITY_REPURPOSED')) return error('INVALID_CATALOG', 422);
    console.error(JSON.stringify({ event: 'catalog_publish_failed' }));
    return error('TEMPORARY_FAILURE', 503);
  }
}

async function readCatalog(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
): Promise<Response> {
  if (request.method !== 'GET') return error('METHOD_NOT_ALLOWED', 405);
  if (!(await clerkAuthenticated(request, env))) return error('AUTH_REQUIRED', 401);
  const state = await readState(database);
  if (!state) return error('CATALOG_UNAVAILABLE', 503);
  if (!state.source_document || !state.publication_id || !state.source_fingerprint) {
    return json({ catalog: null, publication_id: null }, 200, { ETag: '"empty"' });
  }
  const etag = `"${state.source_fingerprint}"`;
  if (request.headers.get('If-None-Match') === etag) {
    return new Response(null, { status: 304, headers: { 'Cache-Control': 'private, no-cache', ETag: etag } });
  }
  const source = checkedPrevious(state.source_document);
  if (!source) return error('CATALOG_UNAVAILABLE', 503);
  const path = new URL(request.url).pathname;
  if (path === '/v1/catalog/programs') {
    return json({ publication_id: state.publication_id, catalog: source }, 200, { ETag: etag });
  }
  if (path === '/v1/catalog/exercises') {
    return json({ publication_id: state.publication_id, exercises: source.exercises }, 200, { ETag: etag });
  }
  const programKey = path.match(/^\/v1\/catalog\/programs\/([^/]+)$/)?.[1];
  if (programKey) {
    const program = source.programs.find(item => item.key === decodeURIComponent(programKey));
    return program
      ? json({ publication_id: state.publication_id, program, exercises: source.exercises }, 200, { ETag: etag })
      : error('PROGRAM_NOT_FOUND', 404);
  }
  return json({ publication_id: state.publication_id, catalog: source }, 200, { ETag: etag });
}

export async function handleCatalogRequest(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
): Promise<Response> {
  const path = new URL(request.url).pathname;
  try {
    if (path === '/v1/maintenance/catalog/preview') return await reviewCatalog(request, env, database);
    if (path === '/v1/maintenance/catalog/publish') return await publishCatalog(request, env, database);
    if (path === '/v1/catalog' || path === '/v1/catalog/programs'
        || path === '/v1/catalog/exercises' || path.startsWith('/v1/catalog/programs/')) {
      return await readCatalog(request, env, database);
    }
    return error('NOT_FOUND', 404);
  } catch {
    console.error(JSON.stringify({ event: 'catalog_request_failed' }));
    return error(path.startsWith('/v1/catalog') ? 'CATALOG_UNAVAILABLE' : 'TEMPORARY_FAILURE', 503);
  }
}
