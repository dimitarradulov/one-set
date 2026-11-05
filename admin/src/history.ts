import { verifyCloudflareAccess, type AccessConfiguration } from '../../worker/src/cloudflare-access';
import { validateCatalogSource, type CatalogSource } from '../../worker/src/catalog-validation';
import type { JWTVerifyGetKey } from 'jose';
import { publishCatalogSource, readCurrentCatalog, reviewCatalogSource } from './catalog-maintenance';

export interface HistoryEnvironment extends AccessConfiguration {
  CATALOG_ENVIRONMENT: string;
  CATALOG_API_BASE_URL: string;
  CATALOG_PUBLISH_TOKEN?: string;
}

export interface HistoryDependencies {
  keySource?: JWTVerifyGetKey;
  fetcher?: typeof fetch;
  verify?: (request: Request, configuration: AccessConfiguration, keySource?: JWTVerifyGetKey) => Promise<boolean>;
}

export interface PublicationSummary {
  publication_id: string;
  source_fingerprint: string;
  published_at: string;
}

export interface HistoricalPublication extends PublicationSummary {
  source: CatalogSource;
}

export interface CurrentPublication {
  publication_id: string;
  source_fingerprint: string;
  source: CatalogSource;
}

export type HistoryActionResult =
  | { view: 'history-review'; publication: HistoricalPublication; current: CurrentPublication; candidate: CatalogSource;
      changes: HistoryChange[]; affectedPrograms: string[]; sourceFingerprint: string; backendFingerprint: string;
      previewID: string; retained: RetainedCounts }
  | { view: 'history-success'; publicationID: string }
  | { view: 'history-error'; status: number; title: string; detail: string; publicationID?: string; retry?: HistoryRetry };

export interface HistoryChange {
  kind: string;
  name?: string;
  detail?: string;
  program_key?: string;
  program_name?: string;
}

export interface RetainedCounts {
  programs: number;
  workouts: number;
  slots: number;
  exercises: number;
}

export interface HistoryRetry {
  publicationID: string;
  publicationFingerprint: string;
  catalogSource: string;
  sourceFingerprint: string;
  backendFingerprint: string;
  previewID: string;
}

interface HistoryResponse { current_publication_id: string | null; publications: PublicationSummary[] }

const text = (value: unknown): string => typeof value === 'string' ? value : '';

function configuration(environment: HistoryEnvironment): { base: string } | undefined {
  const base = environment.CATALOG_API_BASE_URL?.trim().replace(/\/$/, '');
  return base ? { base } : undefined;
}

function assertion(request: Request): string | undefined {
  return request.headers.get('Cf-Access-Jwt-Assertion')
    ?? request.headers.get('Cookie')?.split(';').map(value => value.trim())
      .find(value => value.startsWith('CF_Authorization='))?.slice('CF_Authorization='.length);
}

async function authorized(request: Request, environment: HistoryEnvironment, dependencies: HistoryDependencies,
  mutation: boolean): Promise<boolean> {
  if (!environment.ACCESS_TEAM_DOMAIN || !environment.ACCESS_AUDIENCE || !environment.ACCESS_APPROVED_EMAIL) return false;
  if (mutation && (request.method !== 'POST' || request.headers.get('Origin') !== new URL(request.url).origin
    || (request.headers.get('Sec-Fetch-Site') && request.headers.get('Sec-Fetch-Site') !== 'same-origin')
    || request.headers.get('Content-Type')?.split(';')[0]?.trim() !== 'application/x-www-form-urlencoded')) return false;
  return (dependencies.verify ?? verifyCloudflareAccess)(request, environment, dependencies.keySource);
}

async function apiRead<T>(request: Request, environment: HistoryEnvironment, dependencies: HistoryDependencies,
  path: string): Promise<T | undefined> {
  const config = configuration(environment);
  const token = assertion(request);
  if (!config || !token) return undefined;
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${config.base}${path}`, {
      headers: { 'Cf-Access-Jwt-Assertion': token },
    });
    if (!response.ok) return undefined;
    return await response.json() as T;
  } catch { return undefined; }
}

export async function loadPublicationHistory(request: Request, environment: HistoryEnvironment,
  dependencies: HistoryDependencies = {}): Promise<{ publications?: PublicationSummary[]; currentPublicationID?: string | null; error?: Extract<HistoryActionResult, { view: 'history-error' }> }> {
  if (!await authorized(request, environment, dependencies, false)) {
    return { error: { view: 'history-error', status: 401, title: 'Access required', detail: 'Sign in through Cloudflare Access with the approved founder email, then try again.' } };
  }
  const result = await apiRead<HistoryResponse>(request, environment, dependencies, '/v1/maintenance/catalog/publications');
  return result ? { publications: result.publications, currentPublicationID: result.current_publication_id } : {
    error: { view: 'history-error', status: 503, title: 'Publication history unavailable', detail: 'The configured catalog history could not be loaded. No catalog was changed.' },
  };
}

export async function loadHistoricalPublication(request: Request, environment: HistoryEnvironment,
  publicationID: string, dependencies: HistoryDependencies = {}): Promise<HistoricalPublication | undefined> {
  return apiRead<HistoricalPublication>(request, environment, dependencies,
    `/v1/maintenance/catalog/publications/${encodeURIComponent(publicationID)}`);
}

function byKey<T extends { key: string }>(earlier: T[], current: T[], merge: (old: T, live?: T) => T): { values: T[] } {
  const currentByKey = new Map(current.map(item => [item.key, item]));
  const earlierKeys = new Set(earlier.map(item => item.key));
  const values = earlier.map(item => merge(item, currentByKey.get(item.key)));
  values.push(...current.filter(item => !earlierKeys.has(item.key)));
  return { values };
}

function mergeSlot(old: CatalogSource['programs'][number]['workouts'][number]['exercises'][number],
  live?: CatalogSource['programs'][number]['workouts'][number]['exercises'][number]) {
  return { ...live, ...old };
}

function mergeWorkout(old: CatalogSource['programs'][number]['workouts'][number],
  live?: CatalogSource['programs'][number]['workouts'][number]) {
  const slots = byKey(old.exercises, live?.exercises ?? [], (historical, current) => mergeSlot(historical, current));
  let nextPosition = 1;
  const exercises = slots.values.map(slot => slot.removed === true
    ? slot : { ...slot, position: nextPosition++ });
  return { ...live, ...old, exercises };
}

function mergeProgram(old: CatalogSource['programs'][number], live?: CatalogSource['programs'][number]) {
  const workouts = byKey(old.workouts, live?.workouts ?? [], (historical, current) => mergeWorkout(historical, current));
  let nextPosition = 1;
  const orderedWorkouts = workouts.values.map(workout => workout.removed === true
    ? workout : { ...workout, position: nextPosition++ });
  return { ...live, ...old, workouts: orderedWorkouts };
}

/** Applies the historical content for known identities while carrying newer identities forward. */
export function reconcileHistoricalSource(historical: CatalogSource, current: CatalogSource): {
  source: CatalogSource; retained: RetainedCounts;
} {
  const exercises = byKey(historical.exercises, current.exercises, (old, live) => ({ ...live, ...old }));
  const programs = byKey(historical.programs, current.programs, (old, live) => mergeProgram(old, live));
  const retained: RetainedCounts = { programs: 0, workouts: 0, slots: 0, exercises: 0 };
  const historicalPrograms = new Set(historical.programs.map(program => program.key));
  const historicalWorkouts = new Set(historical.programs.flatMap(program => program.workouts.map(workout => workout.key)));
  const historicalSlots = new Set(historical.programs.flatMap(program => program.workouts.flatMap(workout => workout.exercises.map(slot => slot.key))));
  const historicalExercises = new Set(historical.exercises.map(exercise => exercise.key));
  retained.programs = current.programs.filter(program => !historicalPrograms.has(program.key)).length;
  retained.workouts = current.programs.flatMap(program => program.workouts).filter(workout => !historicalWorkouts.has(workout.key)).length;
  retained.slots = current.programs.flatMap(program => program.workouts.flatMap(workout => workout.exercises)).filter(slot => !historicalSlots.has(slot.key)).length;
  retained.exercises = current.exercises.filter(exercise => !historicalExercises.has(exercise.key)).length;
  return { source: { ...historical, ...current, exercises: exercises.values, programs: programs.values }, retained };
}

export async function prepareHistoricalRestoration(request: Request, form: FormData, environment: HistoryEnvironment,
  dependencies: HistoryDependencies = {}): Promise<HistoryActionResult> {
  if (!await authorized(request, environment, dependencies, true)) return {
    view: 'history-error', status: 401, title: 'Access required', detail: 'Sign in through Cloudflare Access with the approved founder email, then try again.',
  };
  if (environment.CATALOG_ENVIRONMENT !== 'development') return {
    view: 'history-error', status: 403, title: 'Editing is disabled', detail: 'Historical corrections are available only for the development catalog until dashboard rollout is complete.',
  };
  const publicationID = text(form.get('publication_id'));
  if (!publicationID) return { view: 'history-error', status: 400, title: 'Publication not selected', detail: 'Choose a retained publication and inspect its source before restoring it.' };
  const [current, historical] = await Promise.all([
    readCurrentCatalog(request, environment, dependencies),
    loadHistoricalPublication(request, environment, publicationID, dependencies),
  ]);
  if (!current) return { view: 'history-error', status: 503, title: 'Catalog storage is unavailable', detail: 'The current catalog could not be read. Nothing has been changed.' };
  if (!historical) return { view: 'history-error', status: 404, title: 'Publication not found', detail: 'That retained publication is unavailable. Reload history and choose another version.' };
  const reconciled = reconcileHistoricalSource(historical.source, current.source);
  const validation = validateCatalogSource(reconciled.source, current.source);
  if (!validation.catalog || validation.errors.length) return {
    view: 'history-error', status: 409, title: 'Historical content needs reconciliation',
    detail: validation.errors.join(' '), publicationID,
  };
  const reviewed = await reviewCatalogSource(request, validation.catalog, current.source_fingerprint, environment, dependencies);
  if (!('review' in reviewed)) return {
    view: 'history-error', status: reviewed.status,
    title: reviewed.status === 409 ? 'Catalog changed' : reviewed.status === 422 ? 'Historical content conflicts with the catalog' : 'Review could not be prepared',
    detail: reviewed.detail, publicationID,
  };
  return { view: 'history-review', publication: historical, current: reviewed.review.current, candidate: reviewed.review.source,
    changes: reviewed.review.changes, affectedPrograms: reviewed.review.affectedPrograms,
    sourceFingerprint: reviewed.review.sourceFingerprint, backendFingerprint: reviewed.review.backendFingerprint,
    previewID: reviewed.review.previewID, retained: reconciled.retained };
}

export async function publishHistoricalRestoration(request: Request, form: FormData, environment: HistoryEnvironment,
  dependencies: HistoryDependencies = {}): Promise<HistoryActionResult> {
  if (!await authorized(request, environment, dependencies, true)) return {
    view: 'history-error', status: 401, title: 'Access required', detail: 'Sign in through Cloudflare Access with the approved founder email, then try again.',
  };
  if (environment.CATALOG_ENVIRONMENT !== 'development') return {
    view: 'history-error', status: 403, title: 'Editing is disabled', detail: 'Historical corrections are available only for the development catalog until dashboard rollout is complete.',
  };
  const publicationID = text(form.get('publication_id'));
  const publicationFingerprint = text(form.get('publication_fingerprint'));
  const submittedSourceFingerprint = text(form.get('source_fingerprint'));
  const backendFingerprint = text(form.get('backend_fingerprint'));
  const previewID = text(form.get('preview_id'));
  let candidate: unknown;
  try { candidate = JSON.parse(text(form.get('catalog_source'))); } catch { candidate = undefined; }
  if (!publicationID || typeof candidate !== 'object' || candidate === null || Array.isArray(candidate)
    || !/^[a-f0-9]{64}$/.test(submittedSourceFingerprint) || !backendFingerprint || !previewID) return {
    view: 'history-error', status: 400, title: 'Review data is incomplete', detail: 'Return to publication history and prepare the correction again.', publicationID,
  };
  const published = await publishCatalogSource(request, { source: candidate, publicationFingerprint,
    sourceFingerprint: submittedSourceFingerprint, backendFingerprint, previewID }, environment, dependencies);
  if (!('publicationID' in published)) return {
    view: 'history-error', status: published.status,
    title: published.status === 409 ? 'Catalog changed before publication' : 'Publication failed',
    detail: published.detail, publicationID,
    ...(published.status === 409 ? {} : { retry: { publicationID, publicationFingerprint, catalogSource: JSON.stringify(candidate),
      sourceFingerprint: submittedSourceFingerprint, backendFingerprint, previewID } }),
  };
  return { view: 'history-success', publicationID: published.publicationID };
}
