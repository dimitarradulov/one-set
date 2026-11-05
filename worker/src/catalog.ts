import { verifyToken } from '@clerk/backend';
import { diffCatalog, validateCatalogSource, type CatalogSource } from './catalog-validation';
import { verifyCloudflareAccess, type AccessConfiguration } from './cloudflare-access';
import type { JWTVerifyGetKey } from 'jose';

export interface CatalogDatabase {
  query(sql: string, params?: string[]): Promise<Record<string, unknown>[]>;
  transaction(sql: string, params?: string[]): Promise<Record<string, unknown>[]>;
}

export interface CatalogConfiguration {
  CLERK_ISSUER: string;
  CLERK_JWT_KEY: string;
  CLERK_AUTHORIZED_PARTIES: string;
  CATALOG_PUBLISH_TOKEN: string;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUDIENCE: string;
  ACCESS_APPROVED_EMAIL: string;
}

interface PublicationState {
  publication_id: string | null;
  source_fingerprint: string | null;
  source_document: unknown;
  repository_sync_status: string | null;
  repository_commit_sha: string | null;
  repository_sync_error: string | null;
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
  const [row] = await database.query(`SELECT state.publication_id, state.source_fingerprint, state.source_document,
      publication.repository_sync_status, publication.repository_commit_sha, publication.repository_sync_error
    FROM public.catalog_state AS state
    LEFT JOIN public.catalog_publications AS publication ON publication.id = state.publication_id
    WHERE state.singleton = true`);
  if (!row) return undefined;
  return {
    publication_id: typeof row.publication_id === 'string' ? row.publication_id : null,
    source_fingerprint: typeof row.source_fingerprint === 'string' ? row.source_fingerprint : null,
    source_document: row.source_document ?? null,
    repository_sync_status: typeof row.repository_sync_status === 'string' ? row.repository_sync_status : null,
    repository_commit_sha: typeof row.repository_commit_sha === 'string' ? row.repository_commit_sha : null,
    repository_sync_error: typeof row.repository_sync_error === 'string' ? row.repository_sync_error : null,
  };
}

function checkedPrevious(value: unknown): CatalogSource | undefined {
  if (value === null || value === undefined) return undefined;
  const { catalog, errors } = validateCatalogSource(value);
  return errors.length === 0 ? catalog : undefined;
}

function currentCatalog(source: CatalogSource): CatalogSource {
  return {
    ...source,
    programs: source.programs.map(program => {
      const workouts = program.workouts
        .filter(workout => workout.removed !== true)
        .map(workout => ({
          ...workout,
          exercises: workout.exercises.filter(slot => slot.removed !== true),
        }));
      return { ...program, training_days_per_week: workouts.length, workouts };
    }),
  };
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
  const catalog = currentCatalog(source);
  const path = new URL(request.url).pathname;
  if (path === '/v1/catalog/programs') {
    return json({ publication_id: state.publication_id, catalog }, 200, { ETag: etag });
  }
  if (path === '/v1/catalog/exercises') {
    return json({ publication_id: state.publication_id, exercises: source.exercises }, 200, { ETag: etag });
  }
  const programKey = path.match(/^\/v1\/catalog\/programs\/([^/]+)$/)?.[1];
  if (programKey) {
    const program = catalog.programs.find(item => item.key === decodeURIComponent(programKey));
    return program
      ? json({ publication_id: state.publication_id, program, exercises: source.exercises }, 200, { ETag: etag })
      : error('PROGRAM_NOT_FOUND', 404);
  }
  return json({ publication_id: state.publication_id, catalog }, 200, { ETag: etag });
}

async function readCatalogSource(
  request: Request,
  env: CatalogConfiguration & AccessConfiguration,
  database: CatalogDatabase,
  controlledAccessKeySource?: JWTVerifyGetKey,
): Promise<Response> {
  if (request.method !== 'GET') return error('METHOD_NOT_ALLOWED', 405);
  if (!env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUDIENCE || !env.ACCESS_APPROVED_EMAIL) {
    return error('TEMPORARY_FAILURE', 503);
  }
  if (!(await verifyCloudflareAccess(request, env, controlledAccessKeySource))) return error('AUTH_REQUIRED', 401);
  const state = await readState(database);
  if (!state?.source_document || !state.publication_id || !state.source_fingerprint) {
    return error('CATALOG_UNAVAILABLE', 503);
  }
  const source = checkedPrevious(state.source_document);
  if (!source) return error('CATALOG_UNAVAILABLE', 503);
  return json({
    source,
    publication_id: state.publication_id,
    current_publication_id: state.publication_id,
    source_fingerprint: state.source_fingerprint,
    repository_sync_status: state.repository_sync_status ?? 'pending',
    repository_commit_sha: state.repository_commit_sha,
    repository_sync_error: state.repository_sync_error,
  });
}

async function publishedOperation(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
  publicationID: string,
): Promise<Response> {
  const secret = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!env.CATALOG_PUBLISH_TOKEN || !(await sameSecret(secret, env.CATALOG_PUBLISH_TOKEN))) {
    return error('FORBIDDEN', 403);
  }
  if (request.method !== 'GET') return error('METHOD_NOT_ALLOWED', 405);
  const [row] = await database.query(`SELECT id, source_fingerprint, source_document,
      repository_sync_status, repository_commit_sha, repository_sync_error, repository_synced_at
    FROM public.catalog_publications WHERE id = $1`, [publicationID]);
  if (!row) return error('PUBLICATION_NOT_FOUND', 404);
  const [state] = await database.query(`SELECT publication_id FROM public.catalog_state WHERE singleton = true`);
  return json({
    publication_id: row.id,
    source_fingerprint: row.source_fingerprint,
    source: row.source_document,
    is_current: state?.publication_id === publicationID,
    current_publication_id: typeof state?.publication_id === 'string' ? state.publication_id : null,
    repository_sync_status: row.repository_sync_status,
    repository_commit_sha: row.repository_commit_sha,
    repository_sync_error: row.repository_sync_error,
    repository_synced_at: row.repository_synced_at,
  });
}

async function updateRepositorySync(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
  publicationID: string,
): Promise<Response> {
  const secret = request.headers.get('Authorization')?.match(/^Bearer ([^\s]+)$/i)?.[1];
  if (!env.CATALOG_PUBLISH_TOKEN || !(await sameSecret(secret, env.CATALOG_PUBLISH_TOKEN))) {
    return error('FORBIDDEN', 403);
  }
  if (request.method !== 'POST') return error('METHOD_NOT_ALLOWED', 405);
  const bodyValue = await readBody(request);
  if (bodyValue instanceof Response) return bodyValue;
  const body = sourceFromBody(bodyValue);
  const status = body?.status;
  if (!['in_progress', 'synchronized', 'failed', 'superseded'].includes(String(status))) {
    return error('INVALID_SYNC_STATUS', 400);
  }
  const syncStatus = String(status);
  const commitSHA = typeof body?.repository_commit_sha === 'string' ? body.repository_commit_sha : null;
  const detail = typeof body?.error === 'string' ? body.error.slice(0, 500) : null;
  const [row] = await database.transaction(`UPDATE public.catalog_publications AS publication
    SET repository_sync_status = $2,
        repository_commit_sha = coalesce(nullif($3, ''), publication.repository_commit_sha),
        repository_sync_error = CASE WHEN $2 = 'failed' THEN nullif($4, '') ELSE NULL END,
        repository_synced_at = CASE WHEN $2 = 'synchronized' THEN now() ELSE publication.repository_synced_at END
    WHERE publication.id = $1
      AND EXISTS (SELECT 1 FROM public.catalog_state WHERE singleton = true AND publication_id = $1)
    RETURNING id, repository_sync_status, repository_commit_sha, repository_sync_error, repository_synced_at`,
  [publicationID, syncStatus, commitSHA ?? '', detail ?? '']);
  if (!row) return error('STALE_PUBLICATION', 409);
  return json({
    publication_id: row.id,
    repository_sync_status: row.repository_sync_status,
    repository_commit_sha: row.repository_commit_sha,
    repository_sync_error: row.repository_sync_error,
    repository_synced_at: row.repository_synced_at,
  });
}

async function authorizeMaintenanceRead(
  request: Request,
  env: CatalogConfiguration & AccessConfiguration,
  controlledAccessKeySource?: JWTVerifyGetKey,
): Promise<boolean> {
  return request.method === 'GET'
    && Boolean(env.ACCESS_TEAM_DOMAIN && env.ACCESS_AUDIENCE && env.ACCESS_APPROVED_EMAIL)
    && verifyCloudflareAccess(request, env, controlledAccessKeySource);
}

async function readPublicationHistory(
  request: Request,
  env: CatalogConfiguration & AccessConfiguration,
  database: CatalogDatabase,
  controlledAccessKeySource?: JWTVerifyGetKey,
): Promise<Response> {
  if (request.method !== 'GET') return error('METHOD_NOT_ALLOWED', 405);
  if (!(await authorizeMaintenanceRead(request, env, controlledAccessKeySource))) return error('AUTH_REQUIRED', 401);
  try {
    const rows = await database.query(`SELECT state.publication_id AS current_publication_id,
      publication.id AS publication_id, publication.source_fingerprint, publication.published_at
      FROM public.catalog_state AS state
      LEFT JOIN public.catalog_publications AS publication ON true
      WHERE state.singleton = true
      ORDER BY publication.published_at DESC NULLS LAST, publication.id DESC`);
    const currentPublicationID = typeof rows[0]?.current_publication_id === 'string' ? rows[0].current_publication_id : null;
    const publications = rows.filter(publication => typeof publication.publication_id === 'string');
    return json({ current_publication_id: currentPublicationID, publications: publications.map(publication => ({
      publication_id: publication.publication_id,
      source_fingerprint: publication.source_fingerprint,
      published_at: publication.published_at,
    })) });
  } catch {
    return error('CATALOG_UNAVAILABLE', 503);
  }
}

async function readHistoricalPublication(
  request: Request,
  env: CatalogConfiguration & AccessConfiguration,
  database: CatalogDatabase,
  controlledAccessKeySource?: JWTVerifyGetKey,
): Promise<Response> {
  if (request.method !== 'GET') return error('METHOD_NOT_ALLOWED', 405);
  if (!(await authorizeMaintenanceRead(request, env, controlledAccessKeySource))) return error('AUTH_REQUIRED', 401);
  const publicationID = new URL(request.url).pathname.match(/^\/v1\/maintenance\/catalog\/publications\/([^/]+)$/)?.[1];
  if (!publicationID) return error('NOT_FOUND', 404);
  try {
    const [publication] = await database.query(`SELECT id AS publication_id, source_fingerprint, published_at, source_document
      FROM public.catalog_publications WHERE id = $1`, [decodeURIComponent(publicationID)]);
    if (!publication) return error('PUBLICATION_NOT_FOUND', 404);
    const source = checkedPrevious(publication.source_document);
    if (!source) return error('CATALOG_UNAVAILABLE', 503);
    return json({
      publication_id: publication.publication_id,
      source_fingerprint: publication.source_fingerprint,
      published_at: publication.published_at,
      source,
    });
  } catch {
    return error('CATALOG_UNAVAILABLE', 503);
  }
}

export async function handleCatalogRequest(
  request: Request,
  env: CatalogConfiguration,
  database: CatalogDatabase,
  controlledAccessKeySource?: JWTVerifyGetKey,
): Promise<Response> {
  const path = new URL(request.url).pathname;
  try {
    const repositorySyncPath = path.match(/^\/v1\/maintenance\/catalog\/publications\/([^/]+)\/repository-sync$/);
    if (repositorySyncPath) return await updateRepositorySync(request, env, database, decodeURIComponent(repositorySyncPath[1]!));
    const publicationPath = path.match(/^\/v1\/maintenance\/catalog\/publications\/([^/]+)$/);
    if (publicationPath) {
      return request.headers.get('Authorization')?.startsWith('Bearer ')
        ? await publishedOperation(request, env, database, decodeURIComponent(publicationPath[1]!))
        : await readHistoricalPublication(request, env, database, controlledAccessKeySource);
    }
    if (path === '/v1/maintenance/catalog/source') {
      return await readCatalogSource(request, env, database, controlledAccessKeySource);
    }
    if (path === '/v1/maintenance/catalog/publications') {
      return await readPublicationHistory(request, env, database, controlledAccessKeySource);
    }
    if (path.startsWith('/v1/maintenance/catalog/publications/')) {
      return await readHistoricalPublication(request, env, database, controlledAccessKeySource);
    }
    if (path === '/v1/maintenance/catalog/preview') return await reviewCatalog(request, env, database);
    if (path === '/v1/maintenance/catalog/publish') return await publishCatalog(request, env, database);
    if (path === '/v1/catalog' || path === '/v1/catalog/programs'
        || path === '/v1/catalog/exercises' || path.startsWith('/v1/catalog/programs/')) {
      return await readCatalog(request, env, database);
    }
    return error('NOT_FOUND', 404);
  } catch {
    console.error(JSON.stringify({ event: 'catalog_request_failed' }));
    return error(path.startsWith('/v1/catalog') || path.startsWith('/v1/maintenance/catalog/publications') || path === '/v1/maintenance/catalog/source'
      ? 'CATALOG_UNAVAILABLE' : 'TEMPORARY_FAILURE', 503);
  }
}
