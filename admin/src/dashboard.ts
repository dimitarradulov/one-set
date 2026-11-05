import { verifyCloudflareAccess, type AccessConfiguration } from '../../worker/src/cloudflare-access';
import type { CatalogSource } from '../../worker/src/catalog-validation';
import type { JWTVerifyGetKey } from 'jose';

export interface DashboardEnvironment extends AccessConfiguration {
  CATALOG_ENVIRONMENT: string;
  CATALOG_API_BASE_URL: string;
}

interface SourceResponse {
  source: CatalogSource;
  publication_id: string;
  source_fingerprint: string;
}

function escapeHTML(value: unknown): string {
  return String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]!);
}

function errorDocument(title: string, detail: string): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta name="robots" content="noindex, nofollow"><title>${escapeHTML(title)} · OneSet</title><link rel="stylesheet" href="/dashboard.css"></head><body><main class="shell"><header class="masthead"><div class="brand">OneSet <span aria-hidden="true">/</span> Catalog</div></header><section class="alert" role="alert"><h1>${escapeHTML(title)}</h1><p>${escapeHTML(detail)}</p></section></main></body></html>`;
}

function renderCatalog(source: CatalogSource, publicationID: string, sourceFingerprint: string,
  environment: string, email: string): string {
  const exerciseByKey = new Map(source.exercises.map(exercise => [exercise.key, exercise]));
  const removedCount = source.programs.filter(program => program.removed === true).length
    + source.programs.flatMap(program => program.workouts).filter(workout => workout.removed === true).length
    + source.programs.flatMap(program => program.workouts.flatMap(workout => workout.exercises))
      .filter(slot => slot.removed === true).length;
  const programs = source.programs.map((program, index) => {
    const workouts = program.workouts.map(workout => {
      const slots = workout.exercises.map(slot => {
        const exerciseName = exerciseByKey.get(slot.exercise)?.name ?? slot.exercise;
        const removed = slot.removed === true ? '<span class="badge removed"> Removed</span>' : '';
        return `<li class="slot${slot.removed ? ' removed' : ''}">${slot.position}. ${escapeHTML(exerciseName)} · ${slot.reps.minimum}–${slot.reps.maximum} ${escapeHTML(slot.scope ?? 'reps')}${removed}</li>`;
      }).join('');
      return `<article class="workout${workout.removed ? ' removed' : ''}"><div class="workout-heading"><span>${workout.position}. ${escapeHTML(workout.name)}${workout.banner ? ` · ${escapeHTML(workout.banner)}` : ''}</span>${workout.removed ? '<span class="badge removed">Removed</span>' : ''}</div><ul class="slots">${slots}</ul></article>`;
    }).join('');
    return `<details class="program"><summary class="program-summary"><span class="program-number">${String(index + 1).padStart(2, '0')}</span><span><span class="program-name">${escapeHTML(program.name)}</span><span class="program-meta">${program.workouts.length} templates · ${program.recommended_weeks} recommended weeks · ${escapeHTML(program.format)}</span></span><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Published'} <span class="chevron" aria-hidden="true">⌄</span></span></summary><div class="program-body"><p class="description"><strong>${escapeHTML(program.key)}</strong><br>${escapeHTML(program.emphasis)}</p>${workouts}</div></details>`;
  }).join('');
  const exercises = source.exercises.map(exercise => `<article class="exercise"><h3>${escapeHTML(exercise.name)}</h3><p class="exercise-key"><code>${escapeHTML(exercise.key)}</code></p><p class="guidance"><strong>Technique</strong> ${escapeHTML(exercise.instructions)}</p><p class="guidance"><strong>Stop</strong> ${escapeHTML(exercise.stopping_guidance)}</p><p class="guidance"><strong>Warmup</strong> ${escapeHTML(exercise.warmup_guidance)}</p><p class="guidance"><strong>Rest</strong> ${exercise.rest_seconds}s · <strong>Default reps</strong> ${exercise.default_reps.minimum}–${exercise.default_reps.maximum}</p></article>`).join('');
  const workoutCount = source.programs.reduce((count, program) => count + program.workouts.length, 0);
  const slotCount = source.programs.reduce((count, program) => count + program.workouts.reduce((sum, workout) => sum + workout.exercises.length, 0), 0);
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta name="robots" content="noindex, nofollow"><title>Catalog · OneSet</title><link rel="stylesheet" href="/dashboard.css"></head><body><main class="shell"><header class="masthead"><div class="brand">OneSet <span aria-hidden="true">/</span> Catalog</div><div class="identity">Signed in as ${escapeHTML(email)}</div></header><section class="intro"><div><p class="eyebrow">Private maintenance · Read only</p><h1>The complete published catalog.</h1></div><div class="environment">Environment <strong>${escapeHTML(environment)}</strong></div></section><div class="summary" aria-label="Catalog summary"><span>${source.programs.length} programs</span><span>${workoutCount} workout templates</span><span>${slotCount} exercise slots</span><span>${source.exercises.length} shared exercises</span>${removedCount > 0 ? `<span>${removedCount} removed records retained</span>` : ''}</div><div class="section-title"><h2>Programs and workout templates</h2><span class="count">Publication ${escapeHTML(publicationID)} · Source ${escapeHTML(sourceFingerprint)}</span></div><section class="program-list" aria-label="Programs">${programs}</section><div class="section-title"><h2>Shared exercises</h2><span class="count">Guidance shared by every program that uses the exercise</span></div><section class="exercise-list" aria-label="Shared exercises">${exercises}</section><footer>Publication ID <code>${escapeHTML(publicationID)}</code> · Fingerprint <code>${escapeHTML(sourceFingerprint)}</code></footer></main></body></html>`;
}

export async function handleDashboardRequest(
  request: Request,
  environment: DashboardEnvironment,
  dependencies: {
    keySource?: JWTVerifyGetKey;
    fetcher?: typeof fetch;
    verify?: (request: Request, configuration: AccessConfiguration, keySource?: JWTVerifyGetKey) => Promise<boolean>;
  } = {},
): Promise<Response> {
  const headers = { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'private, no-store' };
  const respond = (status: number, html: string) => new Response(html, { status, headers });
  if (request.method !== 'GET') {
    return respond(405, errorDocument('Read only dashboard', 'This dashboard only supports catalog browsing.'));
  }
  if (!environment.ACCESS_TEAM_DOMAIN || !environment.ACCESS_AUDIENCE || !environment.ACCESS_APPROVED_EMAIL) {
    return respond(503, errorDocument('Dashboard access is not configured', 'Ask the dashboard administrator to complete the Cloudflare Access setup.'));
  }
  const verify = dependencies.verify ?? verifyCloudflareAccess;
  if (!(await verify(request, environment, dependencies.keySource))) {
    return respond(401, errorDocument('Access required', 'Sign in through the protected Cloudflare Access application using the approved founder email.'));
  }
  const catalogEnvironment = environment.CATALOG_ENVIRONMENT?.trim();
  const apiBase = environment.CATALOG_API_BASE_URL?.trim().replace(/\/$/, '');
  if (!catalogEnvironment || !apiBase) {
    return respond(503, errorDocument('Catalog environment is not configured', 'The dashboard requires an explicit catalog environment and API URL. No catalog was loaded.'));
  }
  const assertion = request.headers.get('Cf-Access-Jwt-Assertion')
    ?? request.headers.get('Cookie')?.split(';').map(value => value.trim())
      .find(value => value.startsWith('CF_Authorization='))?.slice('CF_Authorization='.length);
  try {
    const response = await (dependencies.fetcher ?? fetch)(`${apiBase}/v1/maintenance/catalog/source`, {
      headers: assertion ? { 'Cf-Access-Jwt-Assertion': assertion } : {},
    });
    if (!response.ok) {
      console.error(JSON.stringify({ event: 'catalog_source_read_rejected', status: response.status }));
      const unavailable = response.status === 503;
      return respond(unavailable ? 503 : 502, errorDocument(
        unavailable ? 'Catalog storage is unavailable' : 'The protected catalog read was rejected',
        unavailable ? 'The configured catalog could not be read. No editable catalog is being shown.'
          : `The catalog API returned ${response.status}. Check the Access application and its audience configuration.`,
      ));
    }
    const result = await response.json() as SourceResponse;
    return respond(200, renderCatalog(result.source, result.publication_id, result.source_fingerprint,
      catalogEnvironment, environment.ACCESS_APPROVED_EMAIL));
  } catch {
    return respond(503, errorDocument('Catalog storage is unavailable', `The configured ${catalogEnvironment} catalog API could not be reached. No editable catalog is being shown.`));
  }
}
