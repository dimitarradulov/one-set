import { verifyCloudflareAccess, type AccessConfiguration } from '../../worker/src/cloudflare-access';
import { validateCatalogSource, type CatalogSource } from '../../worker/src/catalog-validation';
import type { JWTVerifyGetKey } from 'jose';
import { synchronizePublication, type RepositorySyncDependencies, type RepositorySyncEnvironment } from './repository-sync';

export interface DashboardEnvironment extends AccessConfiguration {
  CATALOG_ENVIRONMENT: string;
  CATALOG_API_BASE_URL: string;
  CATALOG_PUBLISH_TOKEN?: string;
  CATALOG_REPOSITORY_OWNER?: string;
  CATALOG_REPOSITORY_NAME?: string;
  CATALOG_REPOSITORY_BRANCH?: string;
  CATALOG_REPOSITORY_TOKEN?: string;
}

export interface DashboardDependencies {
  keySource?: JWTVerifyGetKey;
  fetcher?: typeof fetch;
  verify?: (request: Request, configuration: AccessConfiguration, keySource?: JWTVerifyGetKey) => Promise<boolean>;
  repositorySync?: (publicationID: string, environment: RepositorySyncEnvironment,
    dependencies?: RepositorySyncDependencies) => Promise<{ status: 'synchronized' | 'failed' | 'superseded'; publicationID: string; commitSHA?: string; detail?: string }>;
  repositorySyncDependencies?: RepositorySyncDependencies;
}

interface SourceResponse {
  source: CatalogSource;
  publication_id: string;
  source_fingerprint: string;
  repository_sync_status?: string;
  repository_commit_sha?: string | null;
  repository_sync_error?: string | null;
}

export interface ProgramFields {
  program_key: string;
  name: string;
  format: string;
  emphasis: string;
  recommended_weeks: string;
}

export interface ReviewChange {
  kind: string;
  name?: string;
  detail?: string;
  program_key?: string;
  program_name?: string;
}

export type DashboardResult =
  | { view: 'edit'; source: CatalogSource; publicationID: string; sourceFingerprint: string; fields: ProgramFields; errors?: Partial<Record<keyof ProgramFields, string>>; message?: string }
  | { view: 'review'; source: CatalogSource; publicationID: string; sourceFingerprint: string; reviewSourceFingerprint: string; previewID: string; backendFingerprint: string; changes: ReviewChange[]; affectedPrograms: string[]; fields: ProgramFields }
  | { view: 'success'; publicationID: string; repositoryStatus?: 'synchronized' | 'failed' | 'superseded'; repositoryDetail?: string; repositoryCommitSHA?: string }
  | { view: 'error'; title: string; detail: string; status: number; fields?: ProgramFields };

export type DashboardActionKind = 'edit' | 'review' | 'publish' | 'sync';

function text(value: unknown): string { return typeof value === 'string' ? value : ''; }

function html(value: unknown): string {
  return String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]!);
}

function readFields(form: FormData): ProgramFields {
  return {
    program_key: text(form.get('program_key')),
    name: text(form.get('name')),
    format: text(form.get('format')),
    emphasis: text(form.get('emphasis')),
    recommended_weeks: text(form.get('recommended_weeks')),
  };
}

function validateFields(fields: ProgramFields): Partial<Record<keyof ProgramFields, string>> {
  const errors: Partial<Record<keyof ProgramFields, string>> = {};
  if (!fields.name.trim()) errors.name = 'Enter a program name.';
  else if (fields.name.length > 160) errors.name = 'Keep the program name under 160 characters.';
  if (!fields.format.trim()) errors.format = 'Enter the training format.';
  else if (fields.format.length > 120) errors.format = 'Keep the format under 120 characters.';
  if (!fields.emphasis.trim()) errors.emphasis = 'Enter the program emphasis.';
  else if (fields.emphasis.length > 1000) errors.emphasis = 'Keep the emphasis under 1,000 characters.';
  if (!/^\d+$/.test(fields.recommended_weeks) || Number(fields.recommended_weeks) < 1) {
    errors.recommended_weeks = 'Enter a whole number greater than zero.';
  }
  return errors;
}

function updatedSource(source: CatalogSource, fields: ProgramFields): CatalogSource | undefined {
  const programIndex = source.programs.findIndex(program => program.key === fields.program_key);
  if (programIndex < 0) return undefined;
  const programs = source.programs.map((program, index) => index === programIndex ? {
    ...program,
    name: fields.name.trim(),
    format: fields.format.trim(),
    emphasis: fields.emphasis.trim(),
    recommended_weeks: Number(fields.recommended_weeks),
  } : program);
  return { ...source, programs };
}

function apiConfiguration(environment: DashboardEnvironment): { base: string; environmentName: string } | undefined {
  const base = environment.CATALOG_API_BASE_URL?.trim().replace(/\/$/, '');
  const environmentName = environment.CATALOG_ENVIRONMENT?.trim();
  if (!base || !environmentName) return undefined;
  return { base, environmentName };
}

function accessAssertion(request: Request): string | undefined {
  return request.headers.get('Cf-Access-Jwt-Assertion')
    ?? request.headers.get('Cookie')?.split(';').map(value => value.trim())
      .find(value => value.startsWith('CF_Authorization='))?.slice('CF_Authorization='.length);
}

async function authorize(request: Request, environment: DashboardEnvironment, dependencies: DashboardDependencies,
  requireSameOrigin: boolean): Promise<boolean> {
  if (!environment.ACCESS_TEAM_DOMAIN || !environment.ACCESS_AUDIENCE || !environment.ACCESS_APPROVED_EMAIL) return false;
  if (requireSameOrigin) {
    const origin = request.headers.get('Origin');
    const fetchSite = request.headers.get('Sec-Fetch-Site');
    if (origin !== new URL(request.url).origin || (fetchSite && fetchSite !== 'same-origin')) return false;
    if (request.method !== 'POST' || request.headers.get('Content-Type')?.split(';')[0]?.trim() !== 'application/x-www-form-urlencoded') return false;
  }
  return (dependencies.verify ?? verifyCloudflareAccess)(request, environment, dependencies.keySource);
}

async function readPublishedSource(request: Request, environment: DashboardEnvironment,
  dependencies: DashboardDependencies): Promise<SourceResponse | undefined> {
  const configuration = apiConfiguration(environment);
  const assertion = accessAssertion(request);
  if (!configuration || !assertion) return undefined;
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${configuration.base}/v1/maintenance/catalog/source`, {
      headers: { 'Cf-Access-Jwt-Assertion': assertion },
    });
    if (!response.ok) return undefined;
    return await response.json() as SourceResponse;
  } catch { return undefined; }
}

function formPage(view: 'edit' | 'review', data: Extract<DashboardResult, { view: 'edit' | 'review' }>,
  environmentName: string, repositoryTarget: string, email: string): string {
  const chosen = data.source.programs.find(program => program.key === data.fields.program_key);
  const programOptions = data.source.programs.map(program => `<option value="${html(program.key)}"${program.key === data.fields.program_key ? ' selected' : ''}>${html(program.name)}${program.removed ? ' · Removed' : ''}</option>`).join('');
  const errors = data.view === 'edit' ? data.errors ?? {} : {};
  const field = (name: keyof ProgramFields, label: string, value: string, kind = 'text', hint = '') => {
    const error = errors[name];
    const id = `field-${name}`;
    const limit = name === 'name' ? ' maxlength="160"' : name === 'format' ? ' maxlength="120"' : name === 'emphasis' ? ' maxlength="1000"' : '';
    const control = kind === 'textarea'
      ? `<textarea id="${id}" name="${name}" rows="4"${limit} required aria-invalid="${Boolean(error)}"${error ? ` aria-describedby="error-${name}"` : ''}>${html(value)}</textarea>`
      : `<input id="${id}" name="${name}" type="${kind}" value="${html(value)}"${limit}${kind === 'number' ? ' min="1" step="1" inputmode="numeric"' : ''} required aria-invalid="${Boolean(error)}"${error ? ` aria-describedby="error-${name}"` : ''}>`;
    return `<div class="field"><label for="${id}">${html(label)}</label>${control}${hint ? `<p class="hint">${html(hint)}</p>` : ''}${error ? `<p class="field-error" id="error-${name}" role="alert">${html(error)}</p>` : ''}</div>`;
  };
  const hidden = `<input type="hidden" name="program_key" value="${html(data.fields.program_key)}"><input type="hidden" name="publication_fingerprint" value="${html(data.sourceFingerprint)}">`;
  const editForm = `<form method="POST" action="@reviewProgram" class="editor-form">${hidden}<div class="field"><label for="program-picker">Program</label><select id="program-picker" disabled>${programOptions}</select><input type="hidden" name="program_key" value="${html(data.fields.program_key)}"></div>${field('name', 'Program name', data.fields.name)}${field('format', 'Format', data.fields.format)}${field('emphasis', 'Emphasis', data.fields.emphasis, 'textarea')}${field('recommended_weeks', 'Recommended training weeks', data.fields.recommended_weeks, 'number', 'Training weeks describe the program rotation, not calendar dates.')}<div class="form-actions"><button class="button primary" type="submit">Review changes</button><a class="button quiet" href="/">Cancel</a></div></form>`;
  const review = data.view === 'review' ? `<section class="review-block"><div class="review-heading"><div><h2>Review program changes</h2><p>Nothing has been published. Confirm the exact values and both targets before publishing.</p></div><span class="badge target-badge">${html(environmentName)} catalog · repo ${html(repositoryTarget)}</span></div><div class="diff-list">${data.changes.length ? data.changes.map(change => `<div class="diff-row"><span class="change-kind">${html(change.kind)}</span><div><strong>${html(change.name ?? change.program_name ?? 'Program')}</strong>${change.detail ? `<p>${html(change.detail)}</p>` : ''}</div></div>`).join('') : '<p>No catalog fields changed.</p>'}</div><div class="affected"><h3>Affected programs</h3><p>${data.affectedPrograms.length ? data.affectedPrograms.map(html).join(', ') : 'None'}</p></div><div class="review-values"><span>Name <strong>${html(data.fields.name)}</strong></span><span>Format <strong>${html(data.fields.format)}</strong></span><span>Emphasis <strong>${html(data.fields.emphasis)}</strong></span><span>Recommended weeks <strong>${html(data.fields.recommended_weeks)}</strong></span></div><form method="POST" action="@publishProgram" class="publish-form"><input type="hidden" name="program_key" value="${html(data.fields.program_key)}"><input type="hidden" name="name" value="${html(data.fields.name)}"><input type="hidden" name="format" value="${html(data.fields.format)}"><input type="hidden" name="emphasis" value="${html(data.fields.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(data.fields.recommended_weeks)}"><input type="hidden" name="publication_fingerprint" value="${html(data.sourceFingerprint)}"><input type="hidden" name="source_fingerprint" value="${html(data.reviewSourceFingerprint)}"><input type="hidden" name="preview_id" value="${html(data.previewID)}"><input type="hidden" name="backend_fingerprint" value="${html(data.backendFingerprint)}"><button class="button primary" type="submit"${data.changes.length ? '' : ' disabled'}>Publish to ${html(environmentName)}</button><span class="publish-note">${data.changes.length ? 'One explicit publication to the selected development catalog and configured repository branch.' : 'No changes to publish.'}</span></form><form method="POST" action="@editProgram" class="back-form">${hidden}<input type="hidden" name="name" value="${html(data.fields.name)}"><input type="hidden" name="format" value="${html(data.fields.format)}"><input type="hidden" name="emphasis" value="${html(data.fields.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(data.fields.recommended_weeks)}"><button class="button quiet" type="submit">Back to editing</button></form></section>` : '';
  return `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="intro"><div><h1>Program details</h1><p>Update the program description used by lifters. Workouts and training history stay as published.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section><div class="workflow"><span class="step active">Edit</span><span aria-hidden="true">→</span><span class="step${view === 'review' ? ' active' : ''}">Review</span><span aria-hidden="true">→</span><span class="step">Publish</span></div>${view === 'edit' ? `<section class="editor-layout"><aside class="program-rail"><h2>Programs</h2><ul>${data.source.programs.map(program => `<li${program.key === data.fields.program_key ? ' class="selected"' : ''}><span>${html(program.name)}</span><small>${html(program.format)}${program.removed ? ' · Removed' : ''}</small></li>`).join('')}</ul></aside><div class="editor-panel"><div class="panel-heading"><div><h2>Edit details</h2><p>Key <code>${html(chosen?.key)}</code> · Other catalog content is preserved.</p></div><span class="badge">${chosen?.removed ? 'Removed' : 'Published'}</span></div>${Object.keys(errors).length ? `<div class="notice error" role="alert"><strong>Fix ${Object.keys(errors).length} field${Object.keys(errors).length === 1 ? '' : 's'} below.</strong> Your entries are still here.</div>` : ''}${editForm}</div></section>` : review}</main>`;
}

export function renderDashboard(result: DashboardResult | undefined, sourceData: SourceResponse | undefined,
  environment: DashboardEnvironment): string {
  const email = environment.ACCESS_APPROVED_EMAIL ?? '';
  const config = apiConfiguration(environment);
  const environmentName = config?.environmentName ?? 'unconfigured';
  const repositoryTarget = [environment.CATALOG_REPOSITORY_OWNER, environment.CATALOG_REPOSITORY_NAME].every(Boolean)
    && environment.CATALOG_REPOSITORY_BRANCH
    ? `${environment.CATALOG_REPOSITORY_OWNER}/${environment.CATALOG_REPOSITORY_NAME} · ${environment.CATALOG_REPOSITORY_BRANCH}`
    : 'not configured';
  let body: string;
  if (result?.view === 'edit' || result?.view === 'review') {
    body = formPage(result.view, result, environmentName, repositoryTarget, email);
  } else if (result?.view === 'success') {
    const synchronized = result.repositoryStatus === 'synchronized';
    const repositoryMessage = synchronized
      ? `Repository source and the bundled iOS catalog are synchronized${result.repositoryCommitSHA ? ` at <code>${html(result.repositoryCommitSHA.slice(0, 12))}</code>` : ''}.`
      : result.repositoryStatus === 'superseded'
        ? `The database publication completed, but a newer publication is now current. ${html(result.repositoryDetail ?? 'Reload the catalog and synchronize the current version.')}`
        : `The database publication completed and remains live. Repository synchronization is incomplete${result.repositoryDetail ? `: ${html(result.repositoryDetail)}` : '.'} Retry uses this same published version.`;
    const retry = !synchronized && result.repositoryStatus !== 'superseded'
      ? `<form method="POST" action="@syncCatalog"><input type="hidden" name="publication_id" value="${html(result.publicationID)}"><button class="button primary" type="submit">Retry repository sync</button></form>` : '';
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="result ${synchronized ? 'success' : 'error'}" role="${synchronized ? 'status' : 'alert'}"><div class="result-mark" aria-hidden="true">${synchronized ? '✓' : '!'}</div><div><h1>${synchronized ? 'Catalog published and synchronized' : 'Catalog published; repository sync needed'}</h1><p>The development catalog accepted publication <code>${html(result.publicationID)}</code>.</p><p>${repositoryMessage}</p><div class="form-actions">${retry}<a class="button quiet" href="/">Return to catalog</a></div></div></section></main>`;
  } else if (result?.view === 'error') {
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="result error" role="alert"><div class="result-mark" aria-hidden="true">!</div><div><h1>${html(result.title)}</h1><p>${html(result.detail)}</p>${result.fields ? `<form method="POST" action="@editProgram"><input type="hidden" name="program_key" value="${html(result.fields.program_key)}"><input type="hidden" name="name" value="${html(result.fields.name)}"><input type="hidden" name="format" value="${html(result.fields.format)}"><input type="hidden" name="emphasis" value="${html(result.fields.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(result.fields.recommended_weeks)}"><button class="button quiet" type="submit">Return to editing</button></form>` : ''}</div></section></main>`;
  } else if (sourceData) {
    const count = sourceData.source.programs.length;
    const syncStatus = sourceData.repository_sync_status ?? 'pending';
    const syncNotice = syncStatus === 'synchronized' ? '' : `<section class="sync-notice" role="${syncStatus === 'failed' ? 'alert' : 'status'}"><div><h2>${syncStatus === 'failed' ? 'Repository synchronization needs a retry' : syncStatus === 'in_progress' ? 'Repository synchronization did not finish' : 'Repository files are awaiting synchronization'}</h2><p>The database publication is live. This status tracks repository export separately, so an export problem does not roll back the catalog used by lifters.${sourceData.repository_sync_error ? ` Last result: ${html(sourceData.repository_sync_error)}` : ''}</p></div><form method="POST" action="@syncCatalog"><input type="hidden" name="publication_id" value="${html(sourceData.publication_id)}"><button class="button primary" type="submit">${syncStatus === 'failed' || syncStatus === 'in_progress' ? 'Retry repository sync' : 'Sync repository files'}</button></form></section>`;
    const exerciseByKey = new Map(sourceData.source.exercises.map(exercise => [exercise.key, exercise]));
    const fullCatalog = `<section class="full-catalog"><details><summary>Browse workout templates and shared exercises</summary><div class="full-catalog-content"><h2>Workout templates</h2>${sourceData.source.programs.map(program => `<section class="read-program"><div class="read-program-heading"><h3>${html(program.name)}</h3><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Available'}</span></div><p>${html(program.key)} · ${html(program.format)} · ${program.recommended_weeks} recommended training weeks</p>${program.workouts.map(workout => `<section class="read-workout"><div><strong>${workout.position}. ${html(workout.name)}</strong>${workout.removed ? ' <span class="badge removed">Removed</span>' : ''}</div><ul>${workout.exercises.map(slot => { const exercise = exerciseByKey.get(slot.exercise); return `<li${slot.removed ? ' class="removed-slot"' : ''}>${slot.position}. ${html(exercise?.name ?? slot.exercise)} · ${slot.reps.minimum}–${slot.reps.maximum} ${html(slot.scope ?? 'reps')}${slot.removed ? ' · Removed' : ''}</li>`; }).join('')}</ul></section>`).join('')}</section>`).join('')}<h2>Shared exercises</h2><div class="shared-exercises">${sourceData.source.exercises.map(exercise => `<article><h3>${html(exercise.name)}</h3><code>${html(exercise.key)}</code><p><strong>Technique:</strong> ${html(exercise.instructions)}</p><p><strong>Stop:</strong> ${html(exercise.stopping_guidance)}</p><p><strong>Warmup:</strong> ${html(exercise.warmup_guidance)}</p><p><strong>Rest:</strong> ${exercise.rest_seconds}s · <strong>Default reps:</strong> ${exercise.default_reps.minimum}–${exercise.default_reps.maximum}</p></article>`).join('')}</div></div></details></section>`;
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="intro"><div><h1>Program catalog</h1><p>Choose a program to edit its display details, then review before publishing.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section>${syncNotice}<section class="catalog-panel"><div class="catalog-toolbar"><div><h2>${count} programs in catalog</h2><p class="publication-meta"><span>Publication <code title="${html(sourceData.publication_id)}">${html(sourceData.publication_id)}</code></span><span>Source <code title="${html(sourceData.source_fingerprint)}">${html(sourceData.source_fingerprint)}</code></span></p></div><a class="button quiet history-link" href="/history">Publication history</a></div><div class="catalog-rows">${sourceData.source.programs.map((program, index) => `<article class="catalog-row"><span class="row-index">${String(index + 1).padStart(2, '0')}</span><div class="row-main"><h3>${html(program.name)}</h3><p>${html(program.format)} <span aria-hidden="true">·</span> ${html(program.emphasis)}</p></div><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Available'}</span><form method="POST" action="@editProgram"><input type="hidden" name="program_key" value="${html(program.key)}"><input type="hidden" name="name" value="${html(program.name)}"><input type="hidden" name="format" value="${html(program.format)}"><input type="hidden" name="emphasis" value="${html(program.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(program.recommended_weeks)}"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button quiet" type="submit">Edit details</button></form></article>`).join('')}</div></section>${fullCatalog}</main>`;
  } else {
    const title = 'Catalog unavailable';
    const detail = 'The configured catalog could not be loaded. No empty catalog is being shown.';
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="result error" role="alert"><div class="result-mark" aria-hidden="true">!</div><div><h1>${html(title)}</h1><p>${html(detail)}</p><a class="button quiet" href="/">Try again</a></div></section></main>`;
  }
  const editingEnabled = environment.CATALOG_ENVIRONMENT === 'development';
  const productionNote = !editingEnabled ? '<p class="notice">Editing and publication are disabled for this catalog environment.</p>' : '';
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta name="robots" content="noindex, nofollow"><meta name="color-scheme" content="dark"><title>Catalog · OneSet</title><link rel="stylesheet" href="/dashboard.css"></head><body>${editingEnabled ? body : body.replace(/<form method="POST"[\s\S]*?<\/form>/g, productionNote)}<footer class="page-footer">OneSet catalog maintenance <span>·</span> edits remain in this browser visit only</footer></body></html>`;
}

async function validateRequest(request: Request, environment: DashboardEnvironment, dependencies: DashboardDependencies,
  csrf = true): Promise<DashboardResult | undefined> {
  if (!await authorize(request, environment, dependencies, csrf)) {
    return { view: 'error', status: 401, title: 'Access required', detail: 'Sign in through Cloudflare Access with the approved founder email, then try again.' };
  }
  if (environment.CATALOG_ENVIRONMENT !== 'development') {
    return { view: 'error', status: 403, title: 'Editing is disabled', detail: 'Program editing and publication are available only for the development catalog until dashboard rollout is complete.' };
  }
  return undefined;
}

async function preview(source: CatalogSource, environment: DashboardEnvironment,
  dependencies: DashboardDependencies): Promise<{ previewID: string; backendFingerprint: string; changes: ReviewChange[]; affectedPrograms: string[] } | DashboardResult> {
  const config = apiConfiguration(environment);
  const token = environment.CATALOG_PUBLISH_TOKEN;
  if (!config || !token) return { view: 'error', status: 503, title: 'Publishing is not configured', detail: 'The dashboard administrator must configure the server-side publisher credential.' };
  const normalized = JSON.stringify(source);
  const sourceFingerprint = await sha256(normalized);
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${config.base}/v1/maintenance/catalog/preview`, {
      method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ source, source_fingerprint: sourceFingerprint }),
    });
    const result = await response.json() as { preview_id?: string; backend_fingerprint?: string; changes?: ReviewChange[]; affected_programs?: string[]; error?: { code?: string; details?: string[] } };
    if (!response.ok || !result.preview_id || !result.backend_fingerprint) {
      if (response.status === 422) return { view: 'error', status: 422, title: 'Catalog validation failed', detail: result.error?.details?.join(' ') ?? 'Correct the program details and review again.' };
      if (response.status === 403) return { view: 'error', status: 403, title: 'Publication access was denied', detail: 'The development catalog rejected the server publisher credential. Ask the dashboard administrator to check its configuration.' };
      return { view: 'error', status: response.status === 409 ? 409 : 503, title: response.status === 409 ? 'Catalog changed' : 'Catalog service unavailable', detail: response.status === 409 ? 'The published catalog changed during review. Reload it and review your changes again.' : 'The catalog service could not prepare a review. Your entries are still in this response; retry when the service is available.' };
    }
    return { previewID: result.preview_id, backendFingerprint: result.backend_fingerprint,
      changes: result.changes ?? [], affectedPrograms: result.affected_programs ?? [] };
  } catch {
    return { view: 'error', status: 503, title: 'Catalog service unavailable', detail: 'The catalog service could not prepare a review. Retry when the service is available.' };
  }
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
}

export async function handleDashboardAction(kind: DashboardActionKind, request: Request, form: FormData,
  environment: DashboardEnvironment, dependencies: DashboardDependencies = {}): Promise<DashboardResult> {
  const accessError = await validateRequest(request, environment, dependencies);
  if (accessError) return accessError;
  if (kind === 'sync') {
    const publicationID = text(form.get('publication_id'));
    if (!publicationID || !environment.CATALOG_PUBLISH_TOKEN) {
      return { view: 'error', status: 400, title: 'Synchronization is unavailable', detail: 'The published catalog identity or server publisher credential is missing.' };
    }
    const sync = await (dependencies.repositorySync ?? synchronizePublication)(publicationID,
      environment as RepositorySyncEnvironment, dependencies.repositorySyncDependencies);
    return { view: 'success', publicationID, repositoryStatus: sync.status,
      ...(sync.detail ? { repositoryDetail: sync.detail } : {}),
      ...(sync.commitSHA ? { repositoryCommitSHA: sync.commitSHA } : {}) };
  }
  const sourceData = await readPublishedSource(request, environment, dependencies);
  if (!sourceData) return { view: 'error', status: 503, title: 'Catalog storage is unavailable', detail: 'The configured catalog could not be read. Nothing has been edited or published.' };
  const fields = readFields(form);
  const program = sourceData.source.programs.find(item => item.key === fields.program_key);
  if (!program) return { view: 'error', status: 400, title: 'Program not found', detail: 'Reload the catalog and choose a program that is still published.' };
  const publicationFingerprint = text(form.get('publication_fingerprint'));
  const retrySource = kind === 'publish' ? updatedSource(sourceData.source, fields) : undefined;
  const retrySourceFingerprint = retrySource ? await sha256(JSON.stringify(retrySource)) : '';
  const retryPreviewID = text(form.get('preview_id'));
  const retryBackendFingerprint = text(form.get('backend_fingerprint'));
  const isConfirmedRetry = kind === 'publish'
    && publicationFingerprint !== sourceData.source_fingerprint
    && sourceData.source_fingerprint === text(form.get('source_fingerprint'))
    && retrySourceFingerprint === sourceData.source_fingerprint
    && retryPreviewID === await sha256(`${retryBackendFingerprint}\n${retrySourceFingerprint}`);
  if (publicationFingerprint && publicationFingerprint !== sourceData.source_fingerprint && !isConfirmedRetry) {
    return { view: 'error', status: 409, title: 'Catalog changed', detail: 'The published catalog changed after this page loaded. Reload it, then apply your edits again.', fields };
  }
  const errors = validateFields(fields);
  if (kind === 'edit' || Object.keys(errors).length > 0) {
    return { view: 'edit', source: sourceData.source, publicationID: sourceData.publication_id,
      sourceFingerprint: sourceData.source_fingerprint, fields, ...(Object.keys(errors).length ? { errors } : {}) };
  }
  if (!environment.CATALOG_PUBLISH_TOKEN) return { view: 'error', status: 503, title: 'Publishing is not configured', detail: 'The server-side publisher credential is missing.' };
  const candidate = updatedSource(sourceData.source, fields);
  if (!candidate) return { view: 'error', status: 400, title: 'Program not found', detail: 'Reload the catalog and choose a program that is still published.' };
  const validation = validateCatalogSource(candidate, sourceData.source);
  if (!validation.catalog || validation.errors.length) {
    return { view: 'edit', source: sourceData.source, publicationID: sourceData.publication_id,
      sourceFingerprint: sourceData.source_fingerprint, fields,
      errors: { name: validation.errors.join(' ') } };
  }
  if (kind === 'review') {
    const previewResult = await preview(validation.catalog, environment, dependencies);
    if ('view' in previewResult) return { ...previewResult, fields } as DashboardResult;
    return { view: 'review', source: sourceData.source, publicationID: sourceData.publication_id,
      sourceFingerprint: sourceData.source_fingerprint, reviewSourceFingerprint: await sha256(JSON.stringify(validation.catalog)), previewID: previewResult.previewID,
      backendFingerprint: previewResult.backendFingerprint, changes: previewResult.changes,
      affectedPrograms: previewResult.affectedPrograms, fields };
  }
  if (kind === 'publish') {
    const submittedSourceFingerprint = text(form.get('source_fingerprint'));
    const submittedBackendFingerprint = text(form.get('backend_fingerprint'));
    const submittedPreviewID = text(form.get('preview_id'));
    const computedSourceFingerprint = await sha256(JSON.stringify(validation.catalog));
    if (submittedSourceFingerprint !== computedSourceFingerprint
      || submittedSourceFingerprint !== await sha256(JSON.stringify(updatedSource(sourceData.source, fields)))
      || !submittedBackendFingerprint || !submittedPreviewID
      || submittedPreviewID !== await sha256(`${submittedBackendFingerprint}\n${submittedSourceFingerprint}`)) {
      return { view: 'error', status: 409, title: 'Review is out of date', detail: 'The values or publication review changed. Review the program again before publishing.', fields };
    }
    const config = apiConfiguration(environment);
    try {
      const response = await (dependencies.fetcher ?? fetch)(`${config!.base}/v1/maintenance/catalog/publish`, {
        method: 'POST', headers: { Authorization: `Bearer ${environment.CATALOG_PUBLISH_TOKEN}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ source: validation.catalog, source_fingerprint: submittedSourceFingerprint,
          backend_fingerprint: submittedBackendFingerprint, preview_id: submittedPreviewID }),
      });
      const result = await response.json() as { publication_id?: string; error?: { code?: string } };
      if (!response.ok || !result.publication_id) {
        if (response.status === 409 || result.error?.code === 'STALE_PREVIEW') return { view: 'error', status: 409, title: 'Catalog changed before publication', detail: 'Another publication changed the catalog after your review. Reload the catalog and review your edit again.', fields };
        if (response.status === 422) return { view: 'error', status: 422, title: 'Catalog validation failed', detail: 'The catalog rejected these values. Return to editing and correct the program details.', fields };
        if (response.status === 403) return { view: 'error', status: 403, title: 'Publication access was denied', detail: 'The development catalog rejected the server publisher credential. Ask the dashboard administrator to check its configuration.', fields };
        return { view: 'error', status: 503, title: 'Publication failed', detail: 'The catalog service did not confirm this publication. Check the catalog before retrying; the previous complete catalog remains available if the transaction failed.', fields };
      }
      const synchronization = await (dependencies.repositorySync ?? synchronizePublication)(result.publication_id,
        environment as RepositorySyncEnvironment, dependencies.repositorySyncDependencies);
      return { view: 'success', publicationID: result.publication_id, repositoryStatus: synchronization.status,
        ...(synchronization.detail ? { repositoryDetail: synchronization.detail } : {}),
        ...(synchronization.commitSHA ? { repositoryCommitSHA: synchronization.commitSHA } : {}) };
    } catch {
      return { view: 'error', status: 503, title: 'Publication result is uncertain', detail: 'The response was interrupted. The same reviewed publication can be retried safely; reload the catalog first to check whether it completed.', fields };
    }
  }
  return { view: 'edit', source: sourceData.source, publicationID: sourceData.publication_id,
    sourceFingerprint: sourceData.source_fingerprint, fields };
}

export async function loadDashboard(request: Request, environment: DashboardEnvironment,
  dependencies: DashboardDependencies = {}): Promise<{ source?: SourceResponse; error?: DashboardResult }> {
  if (!await authorize(request, environment, dependencies, false)) {
    return { error: { view: 'error', status: 401, title: 'Access required', detail: 'Sign in through the protected Cloudflare Access application using the approved founder email.' } };
  }
  if (!apiConfiguration(environment)) return { error: { view: 'error', status: 503, title: 'Catalog environment is not configured', detail: 'The dashboard requires an explicit catalog environment and API URL. No catalog was loaded.' } };
  const source = await readPublishedSource(request, environment, dependencies);
  return source ? { source } : { error: { view: 'error', status: 503, title: 'Catalog storage is unavailable', detail: 'The configured catalog could not be read. No editable catalog is being shown.' } };
}
