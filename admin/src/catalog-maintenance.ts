import { validateCatalogSource, type CatalogSource } from '../../worker/src/catalog-validation';
import type { HistoryDependencies, HistoryEnvironment, CurrentPublication, HistoryChange } from './history';

export interface CatalogSourceReview {
  current: CurrentPublication;
  source: CatalogSource;
  sourceFingerprint: string;
  backendFingerprint: string;
  previewID: string;
  changes: HistoryChange[];
  affectedPrograms: string[];
}

export type CatalogReviewResult = { review: CatalogSourceReview } | { status: number; detail: string };

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
}

function accessAssertion(request: Request): string | undefined {
  return request.headers.get('Cf-Access-Jwt-Assertion')
    ?? request.headers.get('Cookie')?.split(';').map(value => value.trim())
      .find(value => value.startsWith('CF_Authorization='))?.slice('CF_Authorization='.length);
}

function apiBase(environment: HistoryEnvironment): string | undefined {
  const base = environment.CATALOG_API_BASE_URL?.trim().replace(/\/$/, '');
  return base || undefined;
}

export async function readCurrentCatalog(request: Request, environment: HistoryEnvironment,
  dependencies: HistoryDependencies = {}): Promise<CurrentPublication | undefined> {
  const base = apiBase(environment);
  const assertion = accessAssertion(request);
  if (!base || !assertion) return undefined;
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${base}/v1/maintenance/catalog/source`, {
      headers: { 'Cf-Access-Jwt-Assertion': assertion },
    });
    return response.ok ? await response.json() as CurrentPublication : undefined;
  } catch { return undefined; }
}

/** Shared complete-source review contract for dashboard authoring and history correction. */
export async function reviewCatalogSource(request: Request, source: unknown, publicationFingerprint: string,
  environment: HistoryEnvironment, dependencies: HistoryDependencies = {}): Promise<CatalogReviewResult> {
  if (environment.CATALOG_ENVIRONMENT !== 'development') return { status: 403, detail: 'Publication is disabled outside the development catalog.' };
  const current = await readCurrentCatalog(request, environment, dependencies);
  if (!current) return { status: 503, detail: 'The current catalog could not be read. Nothing has been changed.' };
  if (publicationFingerprint !== current.source_fingerprint) return {
    status: 409, detail: 'The catalog changed during review. Reload it and prepare the complete correction again.',
  };
  const validation = validateCatalogSource(source, current.source);
  if (!validation.catalog || validation.errors.length) return { status: 422, detail: validation.errors.join(' ') };
  const sourceFingerprint = await sha256(JSON.stringify(validation.catalog));
  const base = apiBase(environment);
  if (!base || !environment.CATALOG_PUBLISH_TOKEN) return { status: 503, detail: 'The server-side publisher credential is missing.' };
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${base}/v1/maintenance/catalog/preview`, {
      method: 'POST', headers: { Authorization: `Bearer ${environment.CATALOG_PUBLISH_TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ source: validation.catalog, source_fingerprint: sourceFingerprint }),
    });
    const result = await response.json() as { preview_id?: string; backend_fingerprint?: string; changes?: HistoryChange[];
      affected_programs?: string[]; error?: { details?: string[] } };
    if (!response.ok || !result.preview_id || !result.backend_fingerprint) return {
      status: response.status || 503,
      detail: result.error?.details?.join(' ') ?? (response.status === 409
        ? 'The catalog changed during review. Reload it and prepare the complete correction again.'
        : 'The catalog service could not prepare the review.'),
    };
    return { review: { current, source: validation.catalog, sourceFingerprint, backendFingerprint: result.backend_fingerprint,
      previewID: result.preview_id, changes: result.changes ?? [], affectedPrograms: result.affected_programs ?? [] } };
  } catch { return { status: 503, detail: 'The catalog service could not prepare the review.' }; }
}

/** Publishes exactly the complete source and preview returned by reviewCatalogSource. */
export async function publishCatalogSource(request: Request, input: {
  source: unknown; publicationFingerprint: string; sourceFingerprint: string; backendFingerprint: string; previewID: string;
}, environment: HistoryEnvironment, dependencies: HistoryDependencies = {}): Promise<{ publicationID: string } | { status: number; detail: string }> {
  if (environment.CATALOG_ENVIRONMENT !== 'development') return { status: 403, detail: 'Publication is disabled outside the development catalog.' };
  const current = await readCurrentCatalog(request, environment, dependencies);
  if (!current) return { status: 503, detail: 'The current catalog could not be read. Nothing has been changed.' };
  const validation = validateCatalogSource(input.source, current.source);
  if (!validation.catalog || validation.errors.length || await sha256(JSON.stringify(validation.catalog)) !== input.sourceFingerprint
    || await sha256(`${input.backendFingerprint}\n${input.sourceFingerprint}`) !== input.previewID) return {
    status: 409, detail: 'The correction or its review changed. Prepare it again against the current catalog.',
  };
  const alreadyPublished = current.source_fingerprint === input.sourceFingerprint;
  if (!alreadyPublished && current.source_fingerprint !== input.publicationFingerprint) return {
    status: 409, detail: 'Another publication changed the catalog after this correction was reviewed. Prepare it again.',
  };
  const base = apiBase(environment);
  if (!base || !environment.CATALOG_PUBLISH_TOKEN) return { status: 503, detail: 'The server-side publisher credential is missing.' };
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${base}/v1/maintenance/catalog/publish`, {
      method: 'POST', headers: { Authorization: `Bearer ${environment.CATALOG_PUBLISH_TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ source: validation.catalog, source_fingerprint: input.sourceFingerprint,
        backend_fingerprint: input.backendFingerprint, preview_id: input.previewID }),
    });
    const result = await response.json() as { publication_id?: string };
    if (!response.ok || !result.publication_id) return {
      status: response.status || 503,
      detail: response.status === 409
        ? 'Another publication changed the catalog after review. Prepare the correction again.'
        : 'The result was not confirmed. The previous complete catalog remains available if the transaction failed; retry this same review to resolve an uncertain response.',
    };
    return { publicationID: result.publication_id };
  } catch {
    return { status: 503, detail: 'The response was interrupted. Retry this exact reviewed correction; the publication uses an idempotent version identity.' };
  }
}
