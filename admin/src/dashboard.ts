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

export interface ExerciseFields {
  exercise_key: string;
  name: string;
  instructions: string;
  stopping_guidance: string;
  warmup_guidance: string;
  rest_seconds: string;
  default_reps_minimum: string;
  default_reps_maximum: string;
  is_new: string;
}

export interface ReviewChange {
  kind: string;
  name?: string;
  detail?: string;
  program_key?: string;
  program_name?: string;
}

export type DashboardResult =
  | { view: 'edit'; contentKind: 'program'; source: CatalogSource; publicationID: string; sourceFingerprint: string; fields: ProgramFields; errors?: Partial<Record<keyof ProgramFields, string>>; catalogErrors?: string[]; message?: string }
  | { view: 'edit'; contentKind: 'exercise'; source: CatalogSource; publicationID: string; sourceFingerprint: string; fields: ExerciseFields; errors?: Partial<Record<keyof ExerciseFields, string>>; message?: string }
  | { view: 'review'; contentKind: 'program'; source: CatalogSource; candidateSource: CatalogSource; publicationID: string; sourceFingerprint: string; reviewSourceFingerprint: string; previewID: string; backendFingerprint: string; changes: ReviewChange[]; affectedPrograms: string[]; fields: ProgramFields }
  | { view: 'review'; contentKind: 'exercise'; source: CatalogSource; candidateSource: CatalogSource; publicationID: string; sourceFingerprint: string; reviewSourceFingerprint: string; previewID: string; backendFingerprint: string; changes: ReviewChange[]; affectedPrograms: string[]; fields: ExerciseFields }
  | { view: 'success'; publicationID: string; repositoryStatus?: 'synchronized' | 'failed' | 'superseded'; repositoryDetail?: string; repositoryCommitSHA?: string }
  | { view: 'error'; title: string; detail: string; status: number; contentKind?: ContentKind; fields?: ContentFields };

export type DashboardActionKind = 'edit' | 'review' | 'publish' | 'sync' | 'edit-exercise' | 'review-exercise' | 'publish-exercise';

type ContentKind = 'program' | 'exercise';
type ContentFields = ProgramFields | ExerciseFields;

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

function readExerciseFields(form: FormData): ExerciseFields {
  return {
    exercise_key: text(form.get('exercise_key')),
    name: text(form.get('name')),
    instructions: text(form.get('instructions')),
    stopping_guidance: text(form.get('stopping_guidance')),
    warmup_guidance: text(form.get('warmup_guidance')),
    rest_seconds: text(form.get('rest_seconds')),
    default_reps_minimum: text(form.get('default_reps_minimum')),
    default_reps_maximum: text(form.get('default_reps_maximum')),
    is_new: text(form.get('is_new')) === 'true' ? 'true' : 'false',
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

function key(prefix: string): string {
  return `${prefix}-${crypto.randomUUID().replaceAll('-', '')}`;
}

function emptyProgram(source: CatalogSource): { source: CatalogSource; fields: ProgramFields } {
  const programKey = key('program');
  const workoutKey = key('workout');
  const slotKey = key('slot');
  const exercise = source.exercises[0];
  const program = {
    key: programKey, name: 'New program', format: '3 workouts', emphasis: '', recommended_weeks: 12,
    workouts: [{ key: workoutKey, name: 'Workout A', position: 1, exercises: [{
      key: slotKey, exercise: exercise?.key ?? '', position: 1, reps: { minimum: 8, maximum: 12 }, scope: 'reps' as const,
    }] }],
  };
  return {
    source: { ...source, programs: [...source.programs, program] },
    fields: { program_key: programKey, name: program.name, format: program.format, emphasis: program.emphasis, recommended_weeks: '12' },
  };
}

function sourceFromForm(form: FormData, published: CatalogSource, fields: ProgramFields): CatalogSource | undefined {
  const serialized = text(form.get('catalog_source'));
  if (serialized) {
    try {
      const candidate = JSON.parse(serialized) as CatalogSource;
      if (candidate && Array.isArray(candidate.programs) && Array.isArray(candidate.exercises)) return candidate;
    } catch { return undefined; }
  }
  return updatedSource(published, fields);
}

function updatedExerciseSource(source: CatalogSource, fields: ExerciseFields): CatalogSource {
  const exerciseIndex = source.exercises.findIndex(exercise => exercise.key === fields.exercise_key);
  const nextExercise = {
    ...(exerciseIndex >= 0 ? source.exercises[exerciseIndex] : {}),
    key: fields.exercise_key.trim(),
    name: fields.name.trim(),
    instructions: fields.instructions.trim(),
    stopping_guidance: fields.stopping_guidance.trim(),
    warmup_guidance: fields.warmup_guidance.trim(),
    rest_seconds: Number(fields.rest_seconds),
    default_reps: { minimum: Number(fields.default_reps_minimum), maximum: Number(fields.default_reps_maximum) },
  };
  const exercises = [...source.exercises];
  if (exerciseIndex < 0) exercises.push(nextExercise);
  else exercises[exerciseIndex] = nextExercise;
  return { ...source, exercises };
}

function validateExerciseFields(fields: ExerciseFields, source: CatalogSource): Partial<Record<keyof ExerciseFields, string>> {
  const errors: Partial<Record<keyof ExerciseFields, string>> = {};
  if (!fields.exercise_key.trim()) errors.exercise_key = 'Enter a stable exercise identity.';
  if (fields.is_new === 'true' && source.exercises.some(exercise => exercise.key === fields.exercise_key.trim())) {
    errors.exercise_key = `The identity “${fields.exercise_key.trim()}” is already used. Choose a new identity.`;
  }
  if (!fields.name.trim()) errors.name = 'Enter an exercise name.';
  if (!fields.instructions.trim()) errors.instructions = 'Enter technique instructions.';
  if (!fields.stopping_guidance.trim()) errors.stopping_guidance = 'Enter stopping guidance.';
  if (!fields.warmup_guidance.trim()) errors.warmup_guidance = 'Enter warmup guidance.';
  if (!/^\d+$/.test(fields.rest_seconds) || Number(fields.rest_seconds) <= 0) {
    errors.rest_seconds = 'Enter a positive whole number of seconds.';
  }
  const minimum = Number(fields.default_reps_minimum);
  const maximum = Number(fields.default_reps_maximum);
  if (!/^\d+$/.test(fields.default_reps_minimum) || minimum < 1 || minimum > 100) {
    errors.default_reps_minimum = 'Enter a whole number from 1 to 100.';
  }
  if (!/^\d+$/.test(fields.default_reps_maximum) || maximum < 1 || maximum > 100) {
    errors.default_reps_maximum = 'Enter a whole number from 1 to 100.';
  } else if (/^\d+$/.test(fields.default_reps_minimum) && maximum < minimum) {
    errors.default_reps_maximum = 'Maximum reps must be at least the minimum.';
  }
  return errors;
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

function exerciseFormPage(view: 'edit' | 'review', data: Extract<DashboardResult, { view: 'edit' | 'review'; contentKind: 'exercise' }>,
  environmentName: string, email: string): string {
  const fields = data.fields;
  const isNew = fields.is_new === 'true';
  const errors = data.view === 'edit' ? data.errors ?? {} : {};
  const field = (name: keyof ExerciseFields, label: string, value: string, kind = 'text', hint = '') => {
    const error = errors[name];
    const id = `field-${name}`;
    const control = kind === 'textarea'
      ? `<textarea id="${id}" name="${name}" rows="5" required aria-invalid="${Boolean(error)}"${error ? ` aria-describedby="error-${name}"` : ''}>${html(value)}</textarea>`
      : `<input id="${id}" name="${name}" type="${kind}" value="${html(value)}"${kind === 'number' ? ' min="1" step="1" inputmode="numeric"' : ''} required aria-invalid="${Boolean(error)}"${error ? ` aria-describedby="error-${name}"` : ''}>`;
    return `<div class="field"><label for="${id}">${html(label)}</label>${control}${hint ? `<p class="hint">${html(hint)}</p>` : ''}${error ? `<p class="field-error" id="error-${name}" role="alert">${html(error)}</p>` : ''}</div>`;
  };
  const hidden = `${isNew ? '' : `<input type="hidden" name="exercise_key" value="${html(fields.exercise_key)}">`}<input type="hidden" name="is_new" value="${isNew}"><input type="hidden" name="publication_fingerprint" value="${html(data.sourceFingerprint)}">`;
  const identityField = isNew
    ? field('exercise_key', 'Stable identity', fields.exercise_key, 'text', 'Use a unique lowercase key with letters, numbers, hyphens, or underscores.')
    : `<div class="field"><span class="field-label">Stable identity</span><code>${html(fields.exercise_key)}</code><p class="hint">Exercise identity is retained when its guidance or display name changes.</p></div>`;
  const editForm = `<form method="POST" action="@reviewExercise" class="editor-form exercise-editor">${hidden}<input type="hidden" name="catalog_source" value="${html(JSON.stringify(data.source))}">${identityField}${field('name', 'Exercise name', fields.name)}${field('instructions', 'Technique instructions', fields.instructions, 'textarea')}${field('stopping_guidance', 'Stopping guidance', fields.stopping_guidance, 'textarea')}${field('warmup_guidance', 'Warmup guidance', fields.warmup_guidance, 'textarea')}${field('rest_seconds', 'Rest duration (seconds)', fields.rest_seconds, 'number') }<fieldset class="rep-range"><legend>Default rep range</legend>${field('default_reps_minimum', 'Minimum reps', fields.default_reps_minimum, 'number')}${field('default_reps_maximum', 'Maximum reps', fields.default_reps_maximum, 'number')}</fieldset><div class="form-actions"><button class="button primary" type="submit">Review changes</button><a class="button quiet" href="/">Cancel</a></div></form>`;
  const newIdentity = isNew ? `<input type="hidden" name="exercise_key" value="${html(fields.exercise_key)}">` : '';
  const review = data.view === 'review' ? `<section class="review-block"><div class="review-heading"><div><h2>Review shared exercise changes</h2><p>These defaults apply to future guidance. Workout slot rep targets and side scope remain as authored.</p></div><span class="badge">${html(environmentName)} target</span></div><div class="diff-list">${data.changes.length ? data.changes.map(change => `<div class="diff-row"><span class="change-kind">${html(change.kind)}</span><div><strong>${html(change.name ?? change.program_name ?? 'Shared exercise')}</strong>${change.program_key ? `<p>Program <code>${html(change.program_name ?? '')}</code> · <code>${html(change.program_key)}</code></p>` : ''}${change.detail ? `<p>${html(change.detail)}</p>` : ''}</div></div>`).join('') : '<p>No catalog fields changed.</p>'}</div><div class="affected"><h3>Affected programs</h3><ul>${data.affectedPrograms.length ? data.affectedPrograms.map(program => `<li>${html(program)}</li>`).join('') : '<li>None</li>'}</ul></div><div class="review-values"><span>Name<strong>${html(fields.name)}</strong></span><span>Technique instructions<strong>${html(fields.instructions)}</strong></span><span>Stopping guidance<strong>${html(fields.stopping_guidance)}</strong></span><span>Warmup guidance<strong>${html(fields.warmup_guidance)}</strong></span><span>Rest<strong>${html(fields.rest_seconds)} seconds</strong></span><span>Default reps<strong>${html(fields.default_reps_minimum)}–${html(fields.default_reps_maximum)}</strong></span></div><form method="POST" action="@publishExercise" class="publish-form">${hidden}${newIdentity}<input type="hidden" name="catalog_source" value="${html(JSON.stringify(data.candidateSource))}"><input type="hidden" name="name" value="${html(fields.name)}"><input type="hidden" name="instructions" value="${html(fields.instructions)}"><input type="hidden" name="stopping_guidance" value="${html(fields.stopping_guidance)}"><input type="hidden" name="warmup_guidance" value="${html(fields.warmup_guidance)}"><input type="hidden" name="rest_seconds" value="${html(fields.rest_seconds)}"><input type="hidden" name="default_reps_minimum" value="${html(fields.default_reps_minimum)}"><input type="hidden" name="default_reps_maximum" value="${html(fields.default_reps_maximum)}"><input type="hidden" name="source_fingerprint" value="${html(data.reviewSourceFingerprint)}"><input type="hidden" name="preview_id" value="${html(data.previewID)}"><input type="hidden" name="backend_fingerprint" value="${html(data.backendFingerprint)}"><button class="button primary" type="submit"${data.changes.length ? '' : ' disabled'}>Publish to ${html(environmentName)}</button><span class="publish-note">${data.changes.length ? 'The full reviewed catalog source will be published.' : 'No changes to publish.'}</span></form><form method="POST" action="@editExercise" class="back-form">${hidden}${newIdentity}<input type="hidden" name="catalog_source" value="${html(JSON.stringify(data.source))}"><input type="hidden" name="name" value="${html(fields.name)}"><input type="hidden" name="instructions" value="${html(fields.instructions)}"><input type="hidden" name="stopping_guidance" value="${html(fields.stopping_guidance)}"><input type="hidden" name="warmup_guidance" value="${html(fields.warmup_guidance)}"><input type="hidden" name="rest_seconds" value="${html(fields.rest_seconds)}"><input type="hidden" name="default_reps_minimum" value="${html(fields.default_reps_minimum)}"><input type="hidden" name="default_reps_maximum" value="${html(fields.default_reps_maximum)}"><button class="button quiet" type="submit">Back to editing</button></form></section>` : '';
  return `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="intro"><div><h1>${isNew ? 'Add a shared exercise' : 'Edit shared exercise'}</h1><p>Shared guidance updates apply to future work. Existing workout prescriptions and recorded sessions keep their captured content.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section><div class="workflow"><span class="step active">Edit</span><span aria-hidden="true">→</span><span class="step${view === 'review' ? ' active' : ''}">Review</span><span aria-hidden="true">→</span><span class="step">Publish</span></div>${view === 'edit' ? `<section class="editor-panel exercise-panel"><div class="panel-heading"><div><h2>${isNew ? 'New movement' : 'Exercise guidance'}</h2><p>Key <code>${html(fields.exercise_key || 'new-exercise')}</code> · Existing identities and additional metadata are preserved.</p></div><span class="badge">${isNew ? 'Not published' : 'Published'}</span></div>${Object.keys(errors).length ? `<div class="notice error" role="alert"><strong>Fix ${Object.keys(errors).length} field${Object.keys(errors).length === 1 ? '' : 's'} below.</strong> Your entries are still here.</div>` : ''}${editForm}</section>` : review}</main>`;
}

function formPage(view: 'edit' | 'review', data: Extract<DashboardResult, { view: 'edit' | 'review' }>,
  environmentName: string, repositoryTarget: string, email: string): string {
  if (data.contentKind === 'exercise') return exerciseFormPage(view, data, environmentName, email);
  const chosen = data.source.programs.find(program => program.key === data.fields.program_key);
  const exerciseByKey = new Map(data.source.exercises.map(exercise => [exercise.key, exercise]));
  const errors = data.view === 'edit' ? data.errors ?? {} : {};
  const catalogErrors = data.view === 'edit' ? data.catalogErrors ?? [] : [];
  const field = (name: keyof ProgramFields, label: string, value: string, kind = 'text', hint = '') => {
    const error = errors[name];
    const id = `field-${name}`;
    const limit = name === 'name' ? ' maxlength="160"' : name === 'format' ? ' maxlength="120"' : name === 'emphasis' ? ' maxlength="1000"' : '';
    const control = kind === 'textarea'
      ? `<textarea id="${id}" name="${name}" rows="4"${limit} required aria-invalid="${Boolean(error)}"${error ? ` aria-describedby="error-${name}"` : ''}>${html(value)}</textarea>`
      : `<input id="${id}" name="${name}" type="${kind}" value="${html(value)}"${limit}${kind === 'number' ? ' min="1" step="1" inputmode="numeric"' : ''} required aria-invalid="${Boolean(error)}"${error ? ` aria-describedby="error-${name}"` : ''}>`;
    return `<div class="field"><label for="${id}">${html(label)}</label>${control}${hint ? `<p class="hint">${html(hint)}</p>` : ''}${error ? `<p class="field-error" id="error-${name}" role="alert">${html(error)}</p>` : ''}</div>`;
  };
  const hidden = `<input type="hidden" name="program_key" value="${html(data.fields.program_key)}"><input type="hidden" name="publication_fingerprint" value="${html(data.sourceFingerprint)}"><input type="hidden" name="catalog_source" value="${html(JSON.stringify(data.source))}">`;
  const exerciseOptions = data.source.exercises.map(exercise => `<option value="${html(exercise.key)}">${html(exercise.name)} · ${html(exercise.key)}</option>`).join('');
  const slotRow = (slot: CatalogSource['programs'][number]['workouts'][number]['exercises'][number], removed = false) => `<div class="slot-row${removed ? ' retained' : ''}" data-slot="${html(slot.key)}" data-original-exercise="${html(slot.exercise)}"${removed ? ' data-removed="true"' : ''}><span class="slot-order">${slot.position}</span><label>Exercise<select data-slot-field="exercise" aria-label="Prescribed exercise">${data.source.exercises.map(exercise => `<option value="${html(exercise.key)}"${exercise.key === slot.exercise ? ' selected' : ''}>${html(exercise.name)} · ${html(exercise.key)}</option>`).join('')}</select></label><label>Rep minimum<input data-slot-field="minimum" type="number" min="1" max="100" value="${html(slot.reps.minimum)}"></label><label>Rep maximum<input data-slot-field="maximum" type="number" min="1" max="100" value="${html(slot.reps.maximum)}"></label><label>Scope<select data-slot-field="scope"><option value="reps"${(slot.scope ?? 'reps') === 'reps' ? ' selected' : ''}>Ordinary reps</option><option value="each_leg"${slot.scope === 'each_leg' ? ' selected' : ''}>Each leg</option><option value="each_side"${slot.scope === 'each_side' ? ' selected' : ''}>Each side</option></select></label><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move exercise up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move exercise down">↓</button><button type="button" class="button quiet" data-toggle-slot>${removed ? 'Restore slot' : 'Remove slot'}</button></div></div>`;
  const workoutRow = (workout: CatalogSource['programs'][number]['workouts'][number], removed = false) => `<article class="workout-card${removed ? ' retained' : ''}" data-workout="${html(workout.key)}"${removed ? ' data-removed="true"' : ''}><header class="workout-card-heading"><div><strong>Workout template</strong><code>${html(workout.key)}</code></div><div class="order-actions">${removed ? '' : '<button type="button" class="button quiet" data-move="up" aria-label="Move workout up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move workout down">↓</button>'}<button type="button" class="button quiet" data-toggle-workout>${removed ? 'Restore template' : 'Remove template'}</button></div></header><div class="workout-fields"><label>Workout name<input data-workout-field="name" value="${html(workout.name)}" required></label><label>Banner identifier<input data-workout-field="banner" value="${html(workout.banner ?? '')}" placeholder="optional-banner-key"><span class="hint">Optional stable banner identifier.</span></label></div><div class="slot-list">${workout.exercises.filter(slot => slot.removed !== true).sort((a, b) => a.position - b.position).map(slot => slotRow(slot)).join('')}</div><details class="retained-slot-list"${workout.exercises.some(slot => slot.removed) ? ' open' : ''}><summary>${workout.exercises.filter(slot => slot.removed).length} removed exercise slot(s)</summary><div class="retained-slot-rows">${workout.exercises.filter(slot => slot.removed).map(slot => slotRow(slot, true)).join('')}</div></details><button type="button" class="button quiet" data-add-slot${removed ? ' disabled' : ''}>Add exercise slot</button></article>`;
  const activeWorkouts = chosen?.workouts.filter(workout => workout.removed !== true).sort((a, b) => a.position - b.position) ?? [];
  const removedWorkouts = chosen?.workouts.filter(workout => workout.removed === true) ?? [];
  const editForm = `<form method="POST" action="@reviewProgram" class="editor-form" id="program-editor">${hidden}<section class="program-fields"><div class="section-heading"><h3>Program details</h3><button class="button quiet" type="button" data-toggle-program>${chosen?.removed ? 'Restore program' : 'Remove program'}</button></div><p class="program-removal-state" role="status">${chosen?.removed ? 'Removed from new selections. Current followers can continue this program.' : 'Removing hides this program from new selections. Current followers can continue it.'}</p>${field('name', 'Program name', data.fields.name)}${field('format', 'Format', data.fields.format)}${field('emphasis', 'Emphasis', data.fields.emphasis, 'textarea')}${field('recommended_weeks', 'Recommended training weeks', data.fields.recommended_weeks, 'number', 'Training weeks describe the program rotation, not calendar dates.')}</section><section class="structure-section"><div class="section-heading"><div><h3>Workout rotation</h3><p>Frequency follows the active workout templates. Active positions are saved consecutively.</p></div><button class="button quiet" type="button" data-add-workout>Add workout template</button></div><div id="workout-list">${activeWorkouts.map(workout => workoutRow(workout)).join('')}</div><details class="retained-records" id="removed-workout-list"${removedWorkouts.length ? ' open' : ''}><summary>${removedWorkouts.length} removed workout template(s)</summary><div class="retained-workouts">${removedWorkouts.map(workout => workoutRow(workout, true)).join('')}</div></details></section>${catalogErrors.length ? `<div class="notice error" role="alert"><strong>Fix these catalog issues before review.</strong><ul>${catalogErrors.map((error: string) => `<li>${html(error)}</li>`).join('')}</ul></div>` : ''}<div class="form-actions"><button class="button primary" type="submit">Review complete program</button><a class="button quiet" href="/">Cancel</a></div></form><template id="slot-template"><div class="slot-row" data-slot=""><span class="slot-order"></span><label>Exercise<select data-slot-field="exercise">${exerciseOptions}</select></label><label>Rep minimum<input data-slot-field="minimum" type="number" min="1" max="100" value="8"></label><label>Rep maximum<input data-slot-field="maximum" type="number" min="1" max="100" value="12"></label><label>Scope<select data-slot-field="scope"><option value="reps">Ordinary reps</option><option value="each_leg">Each leg</option><option value="each_side">Each side</option></select></label><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move exercise up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move exercise down">↓</button><button type="button" class="button quiet" data-toggle-slot>Remove slot</button></div></div></template><template id="workout-template"><article class="workout-card" data-workout=""><header class="workout-card-heading"><div><strong>Workout template</strong><code>New identity</code></div><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move workout up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move workout down">↓</button><button type="button" class="button quiet" data-toggle-workout>Remove template</button></div></header><div class="workout-fields"><label>Workout name<input data-workout-field="name" value="New workout" required></label><label>Banner identifier<input data-workout-field="banner" placeholder="optional-banner-key"><span class="hint">Optional stable banner identifier.</span></label></div><div class="slot-list"></div><details class="retained-slot-list"><summary>0 removed exercise slot(s)</summary><div class="retained-slot-rows"></div></details><button type="button" class="button quiet" data-add-slot>Add exercise slot</button></article></template>`;
  const reviewStructure = chosen ? `<section class="proposed-structure"><h3>Proposed rotation for ${html(chosen.name)}</h3>${chosen.workouts.filter(workout => workout.removed !== true).sort((a, b) => a.position - b.position).map(workout => `<article><div class="proposed-workout"><strong>${workout.position}. ${html(workout.name)}</strong><span>${workout.banner ? `Banner ${html(workout.banner)}` : 'No banner identifier'}</span></div><ol>${workout.exercises.filter(slot => slot.removed !== true).sort((a, b) => a.position - b.position).map(slot => `<li>${html(exerciseByKey.get(slot.exercise)?.name ?? slot.exercise)} · ${slot.reps.minimum}–${slot.reps.maximum} ${html(slot.scope ?? 'reps')} <code>${html(slot.key)}</code></li>`).join('')}</ol></article>`).join('')}</section>` : '';
  const review = data.view === 'review' ? `<section class="review-block"><div class="review-heading"><div><h2>Review complete catalog changes</h2><p>This preview covers the submitted source, including other programs and every retained identity. Nothing has been published yet.</p></div><span class="badge target-badge">${html(environmentName)} catalog · repo ${html(repositoryTarget)}</span></div><div class="diff-list">${data.changes.length ? data.changes.map(change => `<div class="diff-row"><span class="change-kind">${html(change.kind)}</span><div><strong>${html(change.name ?? change.program_name ?? 'Program')}</strong>${change.program_key ? `<code>${html(change.program_key)}</code>` : ''}${change.detail ? `<p>${html(change.detail)}</p>` : ''}</div></div>`).join('') : '<p>No catalog fields changed.</p>'}</div><div class="affected"><h3>Affected programs</h3><p>${data.affectedPrograms.length ? data.affectedPrograms.map(html).join(', ') : 'None'}</p></div><div class="review-values"><span>Program <strong>${html(data.fields.name)} · ${html(data.fields.program_key)}</strong></span><span>Format <strong>${html(data.fields.format)}</strong></span><span>Recommended weeks <strong>${html(data.fields.recommended_weeks)}</strong></span><span>Workout templates <strong>${chosen?.workouts.filter(workout => workout.removed !== true).length ?? 0}</strong></span></div>${reviewStructure}<form method="POST" action="@publishProgram" class="publish-form"><input type="hidden" name="program_key" value="${html(data.fields.program_key)}"><input type="hidden" name="publication_fingerprint" value="${html(data.sourceFingerprint)}"><input type="hidden" name="catalog_source" value="${html(JSON.stringify(data.source))}"><input type="hidden" name="source_fingerprint" value="${html(data.reviewSourceFingerprint)}"><input type="hidden" name="preview_id" value="${html(data.previewID)}"><input type="hidden" name="backend_fingerprint" value="${html(data.backendFingerprint)}"><button class="button primary" type="submit"${data.changes.length ? '' : ' disabled'}>Publish to ${html(environmentName)}</button><span class="publish-note">${data.changes.length ? 'One explicit publication of the reviewed complete source.' : 'No changes to publish.'}</span></form><form method="POST" action="@editProgram" class="back-form">${hidden}<button class="button quiet" type="submit">Back to editing</button></form></section>` : '';
  const script = view === 'edit' ? `<script>(() => {
    const form = document.querySelector('#program-editor');
    const list = document.querySelector('#workout-list');
    const removedWorkouts = document.querySelector('#removed-workout-list .retained-workouts');
    const sourceInput = form.querySelector('[name="catalog_source"]');
    const programKey = form.querySelector('[name="program_key"]').value;
    const uid = prefix => prefix + '-' + crypto.randomUUID().replaceAll('-', '');
    const renumber = container => [...container.children].forEach((row, index) => {
      const order = row.querySelector('.slot-order'); if (order) order.textContent = String(index + 1);
    });
    const disableRetained = (container, toggleSelector) => container.querySelectorAll('input,select,button').forEach(control => {
      if (!control.matches(toggleSelector)) control.disabled = true;
    });
    const enableCard = card => card.querySelectorAll('input,select,button').forEach(control => { control.disabled = false; });
    const updateRetainedSlotCount = card => {
      const rows = card.querySelectorAll('.retained-slot-rows > .slot-row').length;
      card.querySelector('.retained-slot-list summary').textContent = rows + ' removed exercise slot(s)';
    };
    const updateRetainedWorkoutCount = () => {
      const count = removedWorkouts.querySelectorAll(':scope > .workout-card').length;
      removedWorkouts.parentElement.querySelector('summary').textContent = count + ' removed workout template(s)';
      removedWorkouts.parentElement.open = count > 0;
    };
    const sync = () => {
      const source = JSON.parse(sourceInput.value);
      const program = source.programs.find(item => item.key === programKey);
      if (!program) return;
      for (const name of ['name','format','emphasis','recommended_weeks']) {
        const input = form.querySelector('[name="' + name + '"]');
        program[name] = name === 'recommended_weeks' ? Number(input.value) : input.value.trim();
      }
      const existing = new Map(program.workouts.map(item => [item.key, item]));
      const ordered = [];
      [...list.querySelectorAll(':scope > .workout-card')].forEach((card, wi) => {
        const workoutKey = card.dataset.workout;
        const workout = existing.get(workoutKey) || { key: workoutKey, name: '', position: wi + 1, exercises: [] };
        delete workout.removed;
        workout.name = card.querySelector('[data-workout-field="name"]').value.trim();
        const banner = card.querySelector('[data-workout-field="banner"]').value.trim();
        if (banner) workout.banner = banner; else delete workout.banner;
        workout.position = wi + 1;
        const oldSlots = new Map(workout.exercises.map(item => [item.key, item]));
        const slots = [];
        [...card.querySelector('.slot-list').querySelectorAll(':scope > .slot-row')].forEach((row, si) => {
          let slotKey = row.dataset.slot || uid('slot');
          row.dataset.slot = slotKey;
          let slot = oldSlots.get(slotKey);
          const movement = row.querySelector('[data-slot-field="exercise"]').value;
          const identityExercise = row.dataset.originalExercise;
          if ((identityExercise && identityExercise !== movement) || (slot && slot.exercise !== movement)) {
            if (slot) slot.removed = true;
            slotKey = uid('slot'); row.dataset.slot = slotKey; row.dataset.originalExercise = movement; slot = undefined;
          }
          if (!slot) slot = { key: slotKey, exercise: '', position: si + 1, reps: { minimum: 8, maximum: 12 } };
          delete slot.removed;
          slot.exercise = movement; slot.position = si + 1;
          slot.reps = { minimum: Number(row.querySelector('[data-slot-field="minimum"]').value), maximum: Number(row.querySelector('[data-slot-field="maximum"]').value) };
          const scope = row.querySelector('[data-slot-field="scope"]').value;
          if (scope === 'reps') delete slot.scope; else slot.scope = scope;
          slots.push(slot);
        });
        workout.exercises = [...slots, ...workout.exercises.filter(item => item.removed === true)];
        ordered.push(workout);
      });
      const retained = [...removedWorkouts.querySelectorAll(':scope > .workout-card')].map(card => {
        const workout = existing.get(card.dataset.workout); if (workout) workout.removed = true; return workout;
      }).filter(Boolean);
      program.workouts = [...ordered, ...retained];
      sourceInput.value = JSON.stringify(source);
      renumber(list);
    };
    form.querySelector('[data-toggle-program]')?.addEventListener('click', event => {
      const source = JSON.parse(sourceInput.value);
      const program = source.programs.find(item => item.key === programKey);
      if (program.removed === true) delete program.removed; else program.removed = true;
      sourceInput.value = JSON.stringify(source);
      event.currentTarget.textContent = program.removed ? 'Restore program' : 'Remove program';
      form.querySelector('.program-removal-state').textContent = program.removed
        ? 'Removed from new selections. Current followers can continue this program.'
        : 'Removing hides this program from new selections. Current followers can continue it.';
    });
    const addSlot = card => {
      const fragment = document.querySelector('#slot-template').content.cloneNode(true);
      const row = fragment.querySelector('.slot-row'); row.dataset.slot = uid('slot');
      card.querySelector('.slot-list').append(fragment); renumber(card.querySelector('.slot-list')); sync();
    };
    form.addEventListener('click', event => {
      const button = event.target.closest('button'); if (!button) return;
      if (button.hasAttribute('data-add-workout')) {
        const fragment = document.querySelector('#workout-template').content.cloneNode(true);
        const card = fragment.querySelector('.workout-card'); card.dataset.workout = uid('workout');
        const slotFragment = document.querySelector('#slot-template').content.cloneNode(true);
        slotFragment.querySelector('.slot-row').dataset.slot = uid('slot');
        card.querySelector('.slot-list').append(slotFragment); list.append(fragment); sync(); return;
      }
      if (button.hasAttribute('data-add-slot')) { addSlot(button.closest('.workout-card')); return; }
      if (button.hasAttribute('data-toggle-workout')) {
        const card = button.closest('.workout-card');
        const removing = !card.hasAttribute('data-removed');
        if (removing) {
          const source = JSON.parse(sourceInput.value);
          const workout = source.programs.find(item => item.key === programKey)?.workouts.find(item => item.key === card.dataset.workout);
          if (workout) workout.removed = true;
          sourceInput.value = JSON.stringify(source);
          card.dataset.removed = 'true'; card.classList.add('retained');
          card.querySelector('[data-move="up"]')?.remove(); card.querySelector('[data-move="down"]')?.remove();
          button.textContent = 'Restore template'; removedWorkouts.append(card);
          disableRetained(card, '[data-toggle-workout]');
          updateRetainedWorkoutCount();
        } else {
          const source = JSON.parse(sourceInput.value);
          const workout = source.programs.find(item => item.key === programKey)?.workouts.find(item => item.key === card.dataset.workout);
          if (workout) delete workout.removed;
          sourceInput.value = JSON.stringify(source);
          delete card.dataset.removed; card.classList.remove('retained');
          button.textContent = 'Remove template'; enableCard(card);
          card.querySelectorAll('.retained-slot-rows .slot-row').forEach(row => disableRetained(row, '[data-toggle-slot]'));
          updateRetainedSlotCount(card);
          const actions = card.querySelector('.workout-card-heading .order-actions');
          actions.insertAdjacentHTML('afterbegin', '<button type="button" class="button quiet" data-move="up" aria-label="Move workout up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move workout down">↓</button>');
          list.append(card); updateRetainedWorkoutCount();
        }
        sync(); return;
      }
      if (button.hasAttribute('data-toggle-slot')) {
        const row = button.closest('.slot-row');
        const card = button.closest('.workout-card');
        const source = JSON.parse(sourceInput.value);
        const slot = source.programs.find(item => item.key === programKey)?.workouts.find(item => item.key === card.dataset.workout)?.exercises.find(item => item.key === row.dataset.slot);
        if (!slot) return;
        if (row.dataset.removed === 'true') {
          delete slot.removed; delete row.dataset.removed; row.classList.remove('retained');
          button.textContent = 'Remove slot'; enableCard(row); card.querySelector('.slot-list').append(row);
        } else {
          slot.removed = true; row.dataset.removed = 'true'; row.classList.add('retained');
          button.textContent = 'Restore slot';
          const retained = card.querySelector('.retained-slot-list');
          retained.open = true; retained.querySelector('.retained-slot-rows').append(row);
          disableRetained(row, '[data-toggle-slot]');
        }
        updateRetainedSlotCount(card);
        sourceInput.value = JSON.stringify(source); sync(); return;
      }
      const direction = button.dataset.move;
      if (direction) {
        const row = button.closest('.workout-card,.slot-row');
        const sibling = direction === 'up' ? row.previousElementSibling : row.nextElementSibling;
        if (sibling) direction === 'up' ? row.parentElement.insertBefore(row, sibling) : row.parentElement.insertBefore(sibling, row);
        const slots = button.closest('.slot-list'); if (slots) renumber(slots); sync();
      }
    });
    document.querySelectorAll('#removed-workout-list .workout-card').forEach(card => disableRetained(card, '[data-toggle-workout]'));
    document.querySelectorAll('.retained-slot-rows .slot-row').forEach(row => disableRetained(row, '[data-toggle-slot]'));
    form.addEventListener('input', sync);
    form.addEventListener('change', event => {
      const field = event.target;
      if (field.matches?.('[data-slot-field="exercise"]')) {
        const row = field.closest('.slot-row');
        if (row.dataset.originalExercise && row.dataset.originalExercise !== field.value) {
          const source = JSON.parse(sourceInput.value);
          const workout = source.programs.find(item => item.key === programKey)?.workouts.find(item => item.key === row.closest('.workout-card').dataset.workout);
          const oldSlot = workout?.exercises.find(item => item.key === row.dataset.slot); if (oldSlot) oldSlot.removed = true;
          sourceInput.value = JSON.stringify(source); row.dataset.slot = uid('slot'); row.dataset.originalExercise = field.value;
        }
      }
      sync();
    });
    form.addEventListener('submit', sync);
  })();</script>` : '';
  return `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="intro"><div><h1>Program structure</h1><p>Maintain the complete workout rotation and prescriptions. Existing identities and removed records stay in the submitted source.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section><div class="workflow"><span class="step active">Edit</span><span aria-hidden="true">→</span><span class="step${view === 'review' ? ' active' : ''}">Review</span><span aria-hidden="true">→</span><span class="step">Publish</span></div>${view === 'edit' ? `<section class="editor-layout"><aside class="program-rail"><h2>Programs</h2><ul>${data.source.programs.map(program => `<li${program.key === data.fields.program_key ? ' class="selected"' : ''}><span>${html(program.name)}</span><small>${html(program.format)}${program.removed ? ' · Removed' : ''}</small></li>`).join('')}</ul></aside><div class="editor-panel"><div class="panel-heading"><div><h2>${chosen?.removed ? 'Removed program' : 'Program authoring'}</h2><p>Key <code>${html(chosen?.key)}</code> · Training frequency derives from active workout templates.</p></div><span class="badge">${chosen?.removed ? 'Removed' : 'Published'}</span></div>${Object.keys(errors).length ? `<div class="notice error" role="alert"><strong>Fix ${Object.keys(errors).length} program field${Object.keys(errors).length === 1 ? '' : 's'} below.</strong> Your entries are still here.</div>` : ''}${editForm}</div></section>${script}` : review}</main>`;
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
    const returnToEdit = result.fields && result.contentKind === 'exercise' && 'exercise_key' in result.fields
      ? `<form method="POST" action="@editExercise">${Object.entries(result.fields).map(([key, value]) => `<input type="hidden" name="${html(key)}" value="${html(value)}">`).join('')}<button class="button quiet" type="submit">Return to editing</button></form>`
      : result.fields && 'program_key' in result.fields
        ? `<form method="POST" action="@editProgram"><input type="hidden" name="program_key" value="${html(result.fields.program_key)}"><input type="hidden" name="name" value="${html(result.fields.name)}"><input type="hidden" name="format" value="${html(result.fields.format)}"><input type="hidden" name="emphasis" value="${html(result.fields.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(result.fields.recommended_weeks)}"><button class="button quiet" type="submit">Return to editing</button></form>` : '';
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="result error" role="alert"><div class="result-mark" aria-hidden="true">!</div><div><h1>${html(result.title)}</h1><p>${html(result.detail)}</p>${returnToEdit}</div></section></main>`;
  } else if (sourceData) {
    const count = sourceData.source.programs.length;
    const syncStatus = sourceData.repository_sync_status ?? 'pending';
    const syncNotice = syncStatus === 'synchronized' ? '' : `<section class="sync-notice" role="${syncStatus === 'failed' ? 'alert' : 'status'}"><div><h2>${syncStatus === 'failed' ? 'Repository synchronization needs a retry' : syncStatus === 'in_progress' ? 'Repository synchronization did not finish' : 'Repository files are awaiting synchronization'}</h2><p>The database publication is live. This status tracks repository export separately, so an export problem does not roll back the catalog used by lifters.${sourceData.repository_sync_error ? ` Last result: ${html(sourceData.repository_sync_error)}` : ''}</p></div><form method="POST" action="@syncCatalog"><input type="hidden" name="publication_id" value="${html(sourceData.publication_id)}"><button class="button primary" type="submit">${syncStatus === 'failed' || syncStatus === 'in_progress' ? 'Retry repository sync' : 'Sync repository files'}</button></form></section>`;
    const exerciseByKey = new Map(sourceData.source.exercises.map(exercise => [exercise.key, exercise]));
    const exerciseEditForm = (exercise: CatalogSource['exercises'][number]) => `<form method="POST" action="@editExercise"><input type="hidden" name="exercise_key" value="${html(exercise.key)}"><input type="hidden" name="is_new" value="false"><input type="hidden" name="catalog_source" value="${html(JSON.stringify(sourceData.source))}"><input type="hidden" name="name" value="${html(exercise.name)}"><input type="hidden" name="instructions" value="${html(exercise.instructions)}"><input type="hidden" name="stopping_guidance" value="${html(exercise.stopping_guidance)}"><input type="hidden" name="warmup_guidance" value="${html(exercise.warmup_guidance)}"><input type="hidden" name="rest_seconds" value="${exercise.rest_seconds}"><input type="hidden" name="default_reps_minimum" value="${exercise.default_reps.minimum}"><input type="hidden" name="default_reps_maximum" value="${exercise.default_reps.maximum}"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button quiet" type="submit">Edit guidance</button></form>`;
    const fullCatalog = `<section class="full-catalog"><details><summary>Browse workout templates and shared exercises</summary><div class="full-catalog-content"><h2>Workout templates</h2>${sourceData.source.programs.map(program => `<section class="read-program"><div class="read-program-heading"><h3>${html(program.name)}</h3><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Available'}</span></div><p>${html(program.key)} · ${html(program.format)} · ${program.recommended_weeks} recommended training weeks</p>${program.workouts.map(workout => `<section class="read-workout"><div><strong>${workout.position}. ${html(workout.name)}</strong>${workout.removed ? ' <span class="badge removed">Removed</span>' : ''}</div><ul>${workout.exercises.map(slot => { const exercise = exerciseByKey.get(slot.exercise); return `<li${slot.removed ? ' class="removed-slot"' : ''}>${slot.position}. ${html(exercise?.name ?? slot.exercise)} · ${slot.reps.minimum}–${slot.reps.maximum} ${html(slot.scope ?? 'reps')}${slot.removed ? ' · Removed' : ''}</li>`; }).join('')}</ul></section>`).join('')}</section>`).join('')}<div class="exercise-heading"><h2>Shared exercises</h2><form method="POST" action="@editExercise"><input type="hidden" name="is_new" value="true"><input type="hidden" name="catalog_source" value="${html(JSON.stringify(sourceData.source))}"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button primary" type="submit">Add shared exercise</button></form></div><div class="shared-exercises">${sourceData.source.exercises.map(exercise => `<article><div class="exercise-card-heading"><div><h3>${html(exercise.name)}</h3><code>${html(exercise.key)}</code></div>${exerciseEditForm(exercise)}</div><p><strong>Technique:</strong> ${html(exercise.instructions)}</p><p><strong>Stop:</strong> ${html(exercise.stopping_guidance)}</p><p><strong>Warmup:</strong> ${html(exercise.warmup_guidance)}</p><p><strong>Rest:</strong> ${exercise.rest_seconds}s · <strong>Default reps:</strong> ${exercise.default_reps.minimum}–${exercise.default_reps.maximum}</p></article>`).join('')}</div></div></details></section>`;
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header>${syncNotice}<section class="intro"><div><h1>Program catalog</h1><p>Choose a program to edit its display details, then review before publishing.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section><section class="catalog-panel"><div class="catalog-toolbar"><div><h2>${count} programs in catalog</h2><p class="publication-meta"><span>Publication <code title="${html(sourceData.publication_id)}">${html(sourceData.publication_id)}</code></span><span>Source <code title="${html(sourceData.source_fingerprint)}">${html(sourceData.source_fingerprint)}</code></span></p></div><div class="toolbar-actions"><a class="button quiet history-link" href="/history">Publication history</a><form method="POST" action="@editProgram"><input type="hidden" name="create_program" value="1"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button primary" type="submit">Create program</button></form></div></div><div class="catalog-rows">${sourceData.source.programs.map((program, index) => `<article class="catalog-row"><span class="row-index">${String(index + 1).padStart(2, '0')}</span><div class="row-main"><h3>${html(program.name)}</h3><p>${html(program.format)} <span aria-hidden="true">·</span> ${html(program.emphasis)}</p></div><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Available'}</span><form method="POST" action="@editProgram"><input type="hidden" name="program_key" value="${html(program.key)}"><input type="hidden" name="name" value="${html(program.name)}"><input type="hidden" name="format" value="${html(program.format)}"><input type="hidden" name="emphasis" value="${html(program.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(program.recommended_weeks)}"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button quiet" type="submit">Edit details</button></form></article>`).join('')}</div></section>${fullCatalog}</main>`;
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
    if (!publicationID || !environment.CATALOG_PUBLISH_TOKEN) return {
      view: 'error', status: 400, title: 'Synchronization is unavailable',
      detail: 'The published catalog identity or server publisher credential is missing.',
    };
    const sync = await (dependencies.repositorySync ?? synchronizePublication)(publicationID,
      environment as RepositorySyncEnvironment, dependencies.repositorySyncDependencies);
    return { view: 'success', publicationID, repositoryStatus: sync.status,
      ...(sync.detail ? { repositoryDetail: sync.detail } : {}),
      ...(sync.commitSHA ? { repositoryCommitSHA: sync.commitSHA } : {}) };
  }

  const sourceData = await readPublishedSource(request, environment, dependencies);
  if (!sourceData) return { view: 'error', status: 503, title: 'Catalog storage is unavailable',
    detail: 'The configured catalog could not be read. Nothing has been edited or published.' };
  const contentKind: ContentKind = kind.endsWith('-exercise') ? 'exercise' : 'program';
  const phase = kind.startsWith('edit') ? 'edit' : kind.startsWith('review') ? 'review' : 'publish';
  let fields: ContentFields = contentKind === 'exercise' ? readExerciseFields(form) : readFields(form);
  let candidate: CatalogSource | undefined;
  let submittedCatalogSource: CatalogSource | undefined;

  if (contentKind === 'exercise') {
    const serialized = text(form.get('catalog_source'));
    if (!serialized) return { view: 'error', status: 400, title: 'Catalog source is missing',
      detail: 'Reload the exercise editor and submit the complete catalog source again.', contentKind, fields };
    try { submittedCatalogSource = JSON.parse(serialized) as CatalogSource; }
    catch { return { view: 'error', status: 400, title: 'Catalog source is invalid',
      detail: 'Reload the exercise editor and submit the complete catalog source again.', contentKind, fields };
    }
    if (phase !== 'publish' && JSON.stringify(submittedCatalogSource) !== JSON.stringify(sourceData.source)) {
      return { view: 'error', status: 409, title: 'Catalog changed',
        detail: 'The submitted catalog source is out of date. Reload it, then apply your edits again.', contentKind, fields };
    }
    candidate = updatedExerciseSource(sourceData.source, fields as ExerciseFields);
  } else {
    const programFields = fields as ProgramFields;
    if (phase === 'edit' && form.get('create_program') === '1') {
      const draft = emptyProgram(sourceData.source);
      fields = draft.fields;
      candidate = draft.source;
    } else {
      candidate = sourceFromForm(form, sourceData.source, programFields);
    }
    const program = candidate?.programs.find(item => item.key === (fields as ProgramFields).program_key);
    if (!candidate || !program) return { view: 'error', status: 400, title: 'Program source could not be read',
      detail: 'Return to the catalog and reopen the program editor. No published data changed.' };
    fields = { program_key: program.key, name: String(program.name ?? ''), format: String(program.format ?? ''),
      emphasis: String(program.emphasis ?? ''), recommended_weeks: String(program.recommended_weeks ?? '') };
  }

  const publicationFingerprint = text(form.get('publication_fingerprint'));
  const retrySourceFingerprint = phase === 'publish' && candidate ? await sha256(JSON.stringify(candidate)) : '';
  const retryPreviewID = text(form.get('preview_id'));
  const retryBackendFingerprint = text(form.get('backend_fingerprint'));
  const isConfirmedRetry = phase === 'publish'
    && publicationFingerprint !== sourceData.source_fingerprint
    && sourceData.source_fingerprint === text(form.get('source_fingerprint'))
    && retrySourceFingerprint === sourceData.source_fingerprint
    && retryPreviewID === await sha256(`${retryBackendFingerprint}\n${retrySourceFingerprint}`);
  if (publicationFingerprint && publicationFingerprint !== sourceData.source_fingerprint && !isConfirmedRetry) {
    return { view: 'error', status: 409, title: 'Catalog changed',
      detail: 'The published catalog changed after this page loaded. Reload it, then apply your edits again.', contentKind, fields };
  }

  if (phase === 'edit') return { view: 'edit', contentKind, source: candidate ?? sourceData.source,
    publicationID: sourceData.publication_id, sourceFingerprint: sourceData.source_fingerprint, fields } as DashboardResult;
  const errors = contentKind === 'exercise'
    ? validateExerciseFields(fields as ExerciseFields, sourceData.source)
    : validateFields(fields as ProgramFields);
  if (Object.keys(errors).length) return { view: 'edit', contentKind, source: candidate ?? sourceData.source,
    publicationID: sourceData.publication_id, sourceFingerprint: sourceData.source_fingerprint, fields, errors } as DashboardResult;
  if (!environment.CATALOG_PUBLISH_TOKEN) return { view: 'error', status: 503,
    title: 'Publishing is not configured', detail: 'The server-side publisher credential is missing.', contentKind, fields };
  if (!candidate) return { view: 'error', status: 400, title: 'Catalog source is unavailable',
    detail: 'Return to the catalog and reopen the editor. No published data changed.', contentKind, fields };
  if (contentKind === 'exercise' && phase === 'publish' && JSON.stringify(submittedCatalogSource) !== JSON.stringify(candidate)) {
    return { view: 'error', status: 409, title: 'Review is out of date',
      detail: 'The complete catalog source no longer matches the exercise values in this review. Review the catalog changes again before publishing.', contentKind, fields };
  }

  const validation = validateCatalogSource(candidate, sourceData.source);
  if (!validation.catalog || validation.errors.length) {
    if (contentKind === 'exercise') {
      const identityError = validation.errors.find(error => error.includes('exercise')
        && (error.includes('stable lowercase key') || error.includes('duplicate key')));
      return { view: 'edit', contentKind, source: sourceData.source, publicationID: sourceData.publication_id,
        sourceFingerprint: sourceData.source_fingerprint, fields,
        errors: identityError ? { exercise_key: identityError } : { name: validation.errors.join(' ') } } as DashboardResult;
    }
    return { view: 'edit', contentKind, source: candidate, publicationID: sourceData.publication_id,
      sourceFingerprint: sourceData.source_fingerprint, fields, catalogErrors: validation.errors } as DashboardResult;
  }

  if (phase === 'review') {
    const previewResult = await preview(validation.catalog, environment, dependencies);
    if ('view' in previewResult) return { ...previewResult, contentKind, fields } as DashboardResult;
    return { view: 'review', contentKind, source: validation.catalog, candidateSource: validation.catalog,
      publicationID: sourceData.publication_id, sourceFingerprint: sourceData.source_fingerprint,
      reviewSourceFingerprint: await sha256(JSON.stringify(validation.catalog)), previewID: previewResult.previewID,
      backendFingerprint: previewResult.backendFingerprint, changes: previewResult.changes,
      affectedPrograms: previewResult.affectedPrograms, fields } as DashboardResult;
  }

  const submittedSourceFingerprint = text(form.get('source_fingerprint'));
  const submittedBackendFingerprint = text(form.get('backend_fingerprint'));
  const submittedPreviewID = text(form.get('preview_id'));
  const computedSourceFingerprint = await sha256(JSON.stringify(validation.catalog));
  if (submittedSourceFingerprint !== computedSourceFingerprint
    || submittedSourceFingerprint !== await sha256(JSON.stringify(candidate))
    || !submittedBackendFingerprint || !submittedPreviewID
    || submittedPreviewID !== await sha256(`${submittedBackendFingerprint}\n${submittedSourceFingerprint}`)) {
    return { view: 'error', status: 409, title: 'Review is out of date',
      detail: 'The values or publication review changed. Review the catalog changes again before publishing.', contentKind, fields };
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
      if (response.status === 409 || result.error?.code === 'STALE_PREVIEW') return { view: 'error', status: 409,
        title: 'Catalog changed before publication', detail: 'Another publication changed the catalog after your review. Reload the catalog and review your edit again.', contentKind, fields };
      if (response.status === 422) return { view: 'error', status: 422, title: 'Catalog validation failed',
        detail: 'The catalog rejected these values. Return to editing and correct the catalog fields.', contentKind, fields };
      if (response.status === 403) return { view: 'error', status: 403, title: 'Publication access was denied',
        detail: 'The development catalog rejected the server publisher credential. Ask the dashboard administrator to check its configuration.', contentKind, fields };
      return { view: 'error', status: 503, title: 'Publication failed',
        detail: 'The catalog service did not confirm this publication. Check the catalog before retrying; the previous complete catalog remains available if the transaction failed.', contentKind, fields };
    }
    const synchronization = await (dependencies.repositorySync ?? synchronizePublication)(result.publication_id,
      environment as RepositorySyncEnvironment, dependencies.repositorySyncDependencies);
    return { view: 'success', publicationID: result.publication_id, repositoryStatus: synchronization.status,
      ...(synchronization.detail ? { repositoryDetail: synchronization.detail } : {}),
      ...(synchronization.commitSHA ? { repositoryCommitSHA: synchronization.commitSHA } : {}) };
  } catch {
    return { view: 'error', status: 503, title: 'Publication result is uncertain',
      detail: 'The response was interrupted. The same reviewed publication can be retried safely; reload the catalog first to check whether it completed.', contentKind, fields };
  }
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
