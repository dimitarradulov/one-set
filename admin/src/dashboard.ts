import { verifyCloudflareAccess, type AccessConfiguration } from '../../worker/src/cloudflare-access';
import { validateCatalogSource, type CatalogSource } from '../../worker/src/catalog-validation';
import type { JWTVerifyGetKey } from 'jose';

export interface DashboardEnvironment extends AccessConfiguration {
  CATALOG_ENVIRONMENT: string;
  CATALOG_API_BASE_URL: string;
  CATALOG_PUBLISH_TOKEN?: string;
}

export interface DashboardDependencies {
  keySource?: JWTVerifyGetKey;
  fetcher?: typeof fetch;
  verify?: (request: Request, configuration: AccessConfiguration, keySource?: JWTVerifyGetKey) => Promise<boolean>;
}

interface SourceResponse {
  source: CatalogSource;
  publication_id: string;
  source_fingerprint: string;
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
  | { view: 'edit'; source: CatalogSource; publicationID: string; sourceFingerprint: string; fields: ProgramFields; errors?: Partial<Record<keyof ProgramFields, string>>; catalogErrors?: string[]; message?: string }
  | { view: 'review'; source: CatalogSource; publicationID: string; sourceFingerprint: string; reviewSourceFingerprint: string; previewID: string; backendFingerprint: string; changes: ReviewChange[]; affectedPrograms: string[]; fields: ProgramFields }
  | { view: 'success'; publicationID: string }
  | { view: 'error'; title: string; detail: string; status: number; fields?: ProgramFields };

export type DashboardActionKind = 'edit' | 'review' | 'publish';

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
  environmentName: string, email: string): string {
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
  const slotRow = (slot: CatalogSource['programs'][number]['workouts'][number]['exercises'][number]) => `<div class="slot-row" data-slot="${html(slot.key)}" data-original-exercise="${html(slot.exercise)}"><span class="slot-order">${slot.position}</span><label>Exercise<select data-slot-field="exercise" aria-label="Prescribed exercise">${data.source.exercises.map(exercise => `<option value="${html(exercise.key)}"${exercise.key === slot.exercise ? ' selected' : ''}>${html(exercise.name)} · ${html(exercise.key)}</option>`).join('')}</select></label><label>Rep minimum<input data-slot-field="minimum" type="number" min="1" max="100" value="${html(slot.reps.minimum)}"></label><label>Rep maximum<input data-slot-field="maximum" type="number" min="1" max="100" value="${html(slot.reps.maximum)}"></label><label>Scope<select data-slot-field="scope"><option value="reps"${(slot.scope ?? 'reps') === 'reps' ? ' selected' : ''}>Ordinary reps</option><option value="each_leg"${slot.scope === 'each_leg' ? ' selected' : ''}>Each leg</option><option value="each_side"${slot.scope === 'each_side' ? ' selected' : ''}>Each side</option></select></label><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move exercise up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move exercise down">↓</button></div></div>`;
  const workoutRow = (workout: CatalogSource['programs'][number]['workouts'][number]) => `<article class="workout-card" data-workout="${html(workout.key)}"><header class="workout-card-heading"><div><span class="eyebrow">Workout template</span><code>${html(workout.key)}</code></div><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move workout up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move workout down">↓</button></div></header><div class="workout-fields"><label>Workout name<input data-workout-field="name" value="${html(workout.name)}" required></label><label>Banner identifier<input data-workout-field="banner" value="${html(workout.banner ?? '')}" placeholder="optional-banner-key"><span class="hint">Optional stable banner identifier.</span></label></div><div class="slot-list">${workout.exercises.filter(slot => slot.removed !== true).sort((a, b) => a.position - b.position).map(slotRow).join('')}</div><button type="button" class="button quiet" data-add-slot>Add exercise slot</button>${workout.exercises.some(slot => slot.removed) ? `<p class="hint">${workout.exercises.filter(slot => slot.removed).length} removed slot(s) are retained with their identities.</p>` : ''}</article>`;
  const activeWorkouts = chosen?.workouts.filter(workout => workout.removed !== true).sort((a, b) => a.position - b.position) ?? [];
  const removedWorkouts = chosen?.workouts.filter(workout => workout.removed === true) ?? [];
  const editForm = `<form method="POST" action="@reviewProgram" class="editor-form" id="program-editor">${hidden}<section class="program-fields"><h3>Program details</h3>${field('name', 'Program name', data.fields.name)}${field('format', 'Format', data.fields.format)}${field('emphasis', 'Emphasis', data.fields.emphasis, 'textarea')}${field('recommended_weeks', 'Recommended training weeks', data.fields.recommended_weeks, 'number', 'Training weeks describe the program rotation, not calendar dates.')}</section><section class="structure-section"><div class="section-heading"><div><h3>Workout rotation</h3><p>Frequency follows the active workout templates. Active positions are saved consecutively.</p></div><button class="button quiet" type="button" data-add-workout>Add workout template</button></div><div id="workout-list">${activeWorkouts.map(workoutRow).join('')}</div>${removedWorkouts.length ? `<details class="retained-records"><summary>${removedWorkouts.length} removed workout template(s) retained</summary><ul>${removedWorkouts.map(workout => `<li>${html(workout.name)} · <code>${html(workout.key)}</code></li>`).join('')}</ul></details>` : ''}</section>${catalogErrors.length ? `<div class="notice error" role="alert"><strong>Fix these catalog issues before review.</strong><ul>${catalogErrors.map((error: string) => `<li>${html(error)}</li>`).join('')}</ul></div>` : ''}<div class="form-actions"><button class="button primary" type="submit">Review complete program</button><a class="button quiet" href="/">Cancel</a></div></form><template id="slot-template"><div class="slot-row" data-slot=""><span class="slot-order"></span><label>Exercise<select data-slot-field="exercise">${exerciseOptions}</select></label><label>Rep minimum<input data-slot-field="minimum" type="number" min="1" max="100" value="8"></label><label>Rep maximum<input data-slot-field="maximum" type="number" min="1" max="100" value="12"></label><label>Scope<select data-slot-field="scope"><option value="reps">Ordinary reps</option><option value="each_leg">Each leg</option><option value="each_side">Each side</option></select></label><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move exercise up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move exercise down">↓</button></div></div></template><template id="workout-template"><article class="workout-card" data-workout=""><header class="workout-card-heading"><div><span class="eyebrow">Workout template</span><code>New identity</code></div><div class="order-actions"><button type="button" class="button quiet" data-move="up" aria-label="Move workout up">↑</button><button type="button" class="button quiet" data-move="down" aria-label="Move workout down">↓</button></div></header><div class="workout-fields"><label>Workout name<input data-workout-field="name" value="New workout" required></label><label>Banner identifier<input data-workout-field="banner" placeholder="optional-banner-key"><span class="hint">Optional stable banner identifier.</span></label></div><div class="slot-list"></div><button type="button" class="button quiet" data-add-slot>Add exercise slot</button></article></template>`;
  const reviewStructure = chosen ? `<section class="proposed-structure"><h3>Proposed rotation for ${html(chosen.name)}</h3>${chosen.workouts.filter(workout => workout.removed !== true).sort((a, b) => a.position - b.position).map(workout => `<article><div class="proposed-workout"><strong>${workout.position}. ${html(workout.name)}</strong><span>${workout.banner ? `Banner ${html(workout.banner)}` : 'No banner identifier'}</span></div><ol>${workout.exercises.filter(slot => slot.removed !== true).sort((a, b) => a.position - b.position).map(slot => `<li>${html(exerciseByKey.get(slot.exercise)?.name ?? slot.exercise)} · ${slot.reps.minimum}–${slot.reps.maximum} ${html(slot.scope ?? 'reps')} <code>${html(slot.key)}</code></li>`).join('')}</ol></article>`).join('')}</section>` : '';
  const review = data.view === 'review' ? `<section class="review-block"><div class="review-heading"><div><h2>Review complete catalog changes</h2><p>This preview covers the submitted source, including other programs and every retained identity. Nothing has been published yet.</p></div><span class="badge">${html(environmentName)} target</span></div><div class="diff-list">${data.changes.length ? data.changes.map(change => `<div class="diff-row"><span class="change-kind">${html(change.kind)}</span><div><strong>${html(change.name ?? change.program_name ?? 'Program')}</strong>${change.program_key ? `<code>${html(change.program_key)}</code>` : ''}${change.detail ? `<p>${html(change.detail)}</p>` : ''}</div></div>`).join('') : '<p>No catalog fields changed.</p>'}</div><div class="affected"><h3>Affected programs</h3><p>${data.affectedPrograms.length ? data.affectedPrograms.map(html).join(', ') : 'None'}</p></div><div class="review-values"><span>Program <strong>${html(data.fields.name)} · ${html(data.fields.program_key)}</strong></span><span>Format <strong>${html(data.fields.format)}</strong></span><span>Recommended weeks <strong>${html(data.fields.recommended_weeks)}</strong></span><span>Workout templates <strong>${chosen?.workouts.filter(workout => workout.removed !== true).length ?? 0}</strong></span></div>${reviewStructure}<form method="POST" action="@publishProgram" class="publish-form"><input type="hidden" name="program_key" value="${html(data.fields.program_key)}"><input type="hidden" name="publication_fingerprint" value="${html(data.sourceFingerprint)}"><input type="hidden" name="catalog_source" value="${html(JSON.stringify(data.source))}"><input type="hidden" name="source_fingerprint" value="${html(data.reviewSourceFingerprint)}"><input type="hidden" name="preview_id" value="${html(data.previewID)}"><input type="hidden" name="backend_fingerprint" value="${html(data.backendFingerprint)}"><button class="button primary" type="submit"${data.changes.length ? '' : ' disabled'}>Publish to ${html(environmentName)}</button><span class="publish-note">${data.changes.length ? 'One explicit publication of the reviewed complete source.' : 'No changes to publish.'}</span></form><form method="POST" action="@editProgram" class="back-form">${hidden}<button class="button quiet" type="submit">Back to editing</button></form></section>` : '';
  const script = view === 'edit' ? `<script>(() => { const form=document.querySelector('#program-editor'); const list=document.querySelector('#workout-list'); const sourceInput=form.querySelector('[name="catalog_source"]'); const programKey=form.querySelector('[name="program_key"]').value; const uid=prefix=>prefix+'-'+crypto.randomUUID().replaceAll('-',''); const renumber=container=>{ [...container.children].forEach((row,index)=>{const order=row.querySelector('.slot-order'); if(order) order.textContent=String(index+1);}); }; const sync=()=>{ const source=JSON.parse(sourceInput.value); const program=source.programs.find(item=>item.key===programKey); if(!program) return; for(const name of ['name','format','emphasis','recommended_weeks']) { const input=form.querySelector('[name="'+name+'"]'); program[name]=name==='recommended_weeks'?Number(input.value):input.value.trim(); } const existing=new Map(program.workouts.map(item=>[item.key,item])); const ordered=[]; [...list.querySelectorAll(':scope > .workout-card')].forEach((card,wi)=>{const workoutKey=card.dataset.workout; const workout=existing.get(workoutKey)||{key:workoutKey,name:'',position:wi+1,exercises:[]}; workout.name=card.querySelector('[data-workout-field="name"]').value.trim(); const banner=card.querySelector('[data-workout-field="banner"]').value.trim(); if(banner) workout.banner=banner; else delete workout.banner; workout.position=wi+1; const oldSlots=new Map(workout.exercises.map(item=>[item.key,item])); const slots=[]; [...card.querySelector('.slot-list').querySelectorAll(':scope > .slot-row')].forEach((row,si)=>{const slotKey=row.dataset.slot||uid('slot'); row.dataset.slot=slotKey; let slot=oldSlots.get(slotKey); const movement=row.querySelector('[data-slot-field="exercise"]').value; const identityExercise=row.dataset.originalExercise; if((identityExercise && identityExercise!==movement) || (slot && slot.exercise!==movement)) { if(slot) slot.removed=true; slotKey=uid('slot'); row.dataset.slot=slotKey; row.dataset.originalExercise=movement; slot=undefined; } if(!slot) slot={key:slotKey,exercise:'',position:si+1,reps:{minimum:8,maximum:12}}; slot.exercise=movement; slot.position=si+1; slot.reps={minimum:Number(row.querySelector('[data-slot-field="minimum"]').value),maximum:Number(row.querySelector('[data-slot-field="maximum"]').value)}; const scope=row.querySelector('[data-slot-field="scope"]').value; if(scope==='reps') delete slot.scope; else slot.scope=scope; slots.push(slot); }); workout.exercises=[...slots,...workout.exercises.filter(item=>item.removed===true)]; ordered.push(workout); }); program.workouts=[...ordered,...program.workouts.filter(item=>item.removed===true)]; sourceInput.value=JSON.stringify(source); }; const addSlot=card=>{const fragment=document.querySelector('#slot-template').content.cloneNode(true); const row=fragment.querySelector('.slot-row'); row.dataset.slot=uid('slot'); card.querySelector('.slot-list').append(fragment); renumber(card.querySelector('.slot-list')); sync(); }; form.addEventListener('click',event=>{const button=event.target.closest('button'); if(!button) return; if(button.hasAttribute('data-add-workout')) {const fragment=document.querySelector('#workout-template').content.cloneNode(true); const card=fragment.querySelector('.workout-card'); card.dataset.workout=uid('workout'); const slotFragment=document.querySelector('#slot-template').content.cloneNode(true); slotFragment.querySelector('.slot-row').dataset.slot=uid('slot'); card.querySelector('.slot-list').append(slotFragment); list.append(fragment); sync(); return;} if(button.hasAttribute('data-add-slot')) {addSlot(button.closest('.workout-card'));return;} const direction=button.dataset.move; if(direction) {const row=button.closest('.workout-card,.slot-row'); const sibling=direction==='up'?row.previousElementSibling:row.nextElementSibling; if(sibling) direction==='up'?row.parentElement.insertBefore(row,sibling):row.parentElement.insertBefore(sibling,row); const slots=button.closest('.slot-list'); if(slots) renumber(slots); sync(); }}); form.addEventListener('input',sync); form.addEventListener('change',event=>{const field=event.target; if(field.matches?.('[data-slot-field=\"exercise\"]')) {const row=field.closest('.slot-row'); const identityExercise=row.dataset.originalExercise; if(identityExercise && identityExercise!==field.value) {const source=JSON.parse(sourceInput.value); const program=source.programs.find(item=>item.key===programKey); const workout=program?.workouts.find(item=>item.key===row.closest('.workout-card').dataset.workout); const oldSlot=workout?.exercises.find(item=>item.key===row.dataset.slot); if(oldSlot) oldSlot.removed=true; sourceInput.value=JSON.stringify(source); row.dataset.slot=uid('slot'); row.dataset.originalExercise=field.value; }} sync();}); form.addEventListener('submit',sync); })();</script>` : '';
  return `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="intro"><div><h1>Program structure</h1><p>Maintain the complete workout rotation and prescriptions. Existing identities and removed records stay in the submitted source.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section><div class="workflow"><span class="step active">Edit</span><span aria-hidden="true">→</span><span class="step${view === 'review' ? ' active' : ''}">Review</span><span aria-hidden="true">→</span><span class="step">Publish</span></div>${view === 'edit' ? `<section class="editor-layout"><aside class="program-rail"><h2>Programs</h2><ul>${data.source.programs.map(program => `<li${program.key === data.fields.program_key ? ' class="selected"' : ''}><span>${html(program.name)}</span><small>${html(program.format)}${program.removed ? ' · Removed' : ''}</small></li>`).join('')}</ul></aside><div class="editor-panel"><div class="panel-heading"><div><h2>${chosen?.removed ? 'Removed program' : 'Program authoring'}</h2><p>Key <code>${html(chosen?.key)}</code> · Training frequency derives from active workout templates.</p></div><span class="badge">${chosen?.removed ? 'Removed' : 'Published'}</span></div>${Object.keys(errors).length ? `<div class="notice error" role="alert"><strong>Fix ${Object.keys(errors).length} program field${Object.keys(errors).length === 1 ? '' : 's'} below.</strong> Your entries are still here.</div>` : ''}${editForm}</div></section>${script}` : review}</main>`;
}

export function renderDashboard(result: DashboardResult | undefined, sourceData: SourceResponse | undefined,
  environment: DashboardEnvironment): string {
  const email = environment.ACCESS_APPROVED_EMAIL ?? '';
  const config = apiConfiguration(environment);
  const environmentName = config?.environmentName ?? 'unconfigured';
  let body: string;
  if (result?.view === 'edit' || result?.view === 'review') {
    body = formPage(result.view, result, environmentName, email);
  } else if (result?.view === 'success') {
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="result success" role="status"><div class="result-mark" aria-hidden="true">✓</div><div><h1>Catalog published</h1><p>The development catalog accepted publication <code>${html(result.publicationID)}</code>. The app-facing catalog now contains the updated program structure and prescriptions.</p><a class="button primary" href="/">Return to catalog</a></div></section></main>`;
  } else if (result?.view === 'error') {
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="result error" role="alert"><div class="result-mark" aria-hidden="true">!</div><div><h1>${html(result.title)}</h1><p>${html(result.detail)}</p>${result.fields ? `<form method="POST" action="@editProgram"><input type="hidden" name="program_key" value="${html(result.fields.program_key)}"><input type="hidden" name="name" value="${html(result.fields.name)}"><input type="hidden" name="format" value="${html(result.fields.format)}"><input type="hidden" name="emphasis" value="${html(result.fields.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(result.fields.recommended_weeks)}"><button class="button quiet" type="submit">Return to editing</button></form>` : ''}</div></section></main>`;
  } else if (sourceData) {
    const count = sourceData.source.programs.length;
    const exerciseByKey = new Map(sourceData.source.exercises.map(exercise => [exercise.key, exercise]));
    const fullCatalog = `<section class="full-catalog"><details><summary>Browse workout templates and shared exercises</summary><div class="full-catalog-content"><h2>Workout templates</h2>${sourceData.source.programs.map(program => `<section class="read-program"><div class="read-program-heading"><h3>${html(program.name)}</h3><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Available'}</span></div><p>${html(program.key)} · ${html(program.format)} · ${program.recommended_weeks} recommended training weeks</p>${program.workouts.map(workout => `<section class="read-workout"><div><strong>${workout.position}. ${html(workout.name)}</strong>${workout.removed ? ' <span class="badge removed">Removed</span>' : ''}</div><ul>${workout.exercises.map(slot => { const exercise = exerciseByKey.get(slot.exercise); return `<li${slot.removed ? ' class="removed-slot"' : ''}>${slot.position}. ${html(exercise?.name ?? slot.exercise)} · ${slot.reps.minimum}–${slot.reps.maximum} ${html(slot.scope ?? 'reps')}${slot.removed ? ' · Removed' : ''}</li>`; }).join('')}</ul></section>`).join('')}</section>`).join('')}<h2>Shared exercises</h2><div class="shared-exercises">${sourceData.source.exercises.map(exercise => `<article><h3>${html(exercise.name)}</h3><code>${html(exercise.key)}</code><p><strong>Technique:</strong> ${html(exercise.instructions)}</p><p><strong>Stop:</strong> ${html(exercise.stopping_guidance)}</p><p><strong>Warmup:</strong> ${html(exercise.warmup_guidance)}</p><p><strong>Rest:</strong> ${exercise.rest_seconds}s · <strong>Default reps:</strong> ${exercise.default_reps.minimum}–${exercise.default_reps.maximum}</p></article>`).join('')}</div></div></details></section>`;
    body = `<main class="shell"><header class="masthead"><a class="brand" href="/">OneSet <span aria-hidden="true">/</span> Catalog</a><div class="identity">Signed in as ${html(email)}</div></header><section class="intro"><div><h1>Program catalog</h1><p>Create a complete program or edit a program's workout rotation and prescriptions, then review before publishing.</p></div><div class="environment">Target <strong>${html(environmentName)}</strong></div></section><section class="catalog-panel"><div class="catalog-toolbar"><div><h2>${count} programs in catalog</h2><p class="publication-meta"><span>Publication <code title="${html(sourceData.publication_id)}">${html(sourceData.publication_id)}</code></span><span>Source <code title="${html(sourceData.source_fingerprint)}">${html(sourceData.source_fingerprint)}</code></span></p></div><form method="POST" action="@editProgram"><input type="hidden" name="create_program" value="1"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button primary" type="submit">Create program</button></form></div><div class="catalog-rows">${sourceData.source.programs.map((program, index) => `<article class="catalog-row"><span class="row-index">${String(index + 1).padStart(2, '0')}</span><div class="row-main"><h3>${html(program.name)}</h3><p>${html(program.format)} <span aria-hidden="true">·</span> ${html(program.emphasis)}</p></div><span class="badge${program.removed ? ' removed' : ''}">${program.removed ? 'Removed' : 'Available'}</span><form method="POST" action="@editProgram"><input type="hidden" name="program_key" value="${html(program.key)}"><input type="hidden" name="name" value="${html(program.name)}"><input type="hidden" name="format" value="${html(program.format)}"><input type="hidden" name="emphasis" value="${html(program.emphasis)}"><input type="hidden" name="recommended_weeks" value="${html(program.recommended_weeks)}"><input type="hidden" name="publication_fingerprint" value="${html(sourceData.source_fingerprint)}"><button class="button quiet" type="submit">Edit details</button></form></article>`).join('')}</div></section>${fullCatalog}</main>`;
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
  const sourceData = await readPublishedSource(request, environment, dependencies);
  if (!sourceData) return { view: 'error', status: 503, title: 'Catalog storage is unavailable', detail: 'The configured catalog could not be read. Nothing has been edited or published.' };
  let fields = readFields(form);
  let candidate: CatalogSource | undefined;
  if (kind === 'edit' && form.get('create_program') === '1') {
    const draft = emptyProgram(sourceData.source);
    candidate = draft.source;
    fields = draft.fields;
  } else {
    candidate = sourceFromForm(form, sourceData.source, fields);
  }
  const candidateProgram = candidate?.programs.find(item => item.key === fields.program_key);
  if (candidateProgram) {
    fields = { program_key: candidateProgram.key, name: String(candidateProgram.name ?? ''), format: String(candidateProgram.format ?? ''),
      emphasis: String(candidateProgram.emphasis ?? ''), recommended_weeks: String(candidateProgram.recommended_weeks ?? '') };
  }
  if (!candidate || !candidateProgram) return { view: 'error', status: 400, title: 'Program source could not be read', detail: 'Return to the catalog and reopen the program editor. No published data changed.' };
  const publicationFingerprint = text(form.get('publication_fingerprint'));
  const retrySourceFingerprint = kind === 'publish' ? await sha256(JSON.stringify(candidate)) : '';
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
  if (kind === 'edit') return { view: 'edit', source: candidate, publicationID: sourceData.publication_id,
    sourceFingerprint: sourceData.source_fingerprint, fields };
  if (Object.keys(errors).length > 0) return { view: 'edit', source: candidate, publicationID: sourceData.publication_id,
    sourceFingerprint: sourceData.source_fingerprint, fields, errors };
  if (!environment.CATALOG_PUBLISH_TOKEN) return { view: 'error', status: 503, title: 'Publishing is not configured', detail: 'The server-side publisher credential is missing.' };
  const validation = validateCatalogSource(candidate, sourceData.source);
  if (!validation.catalog || validation.errors.length) {
    return { view: 'edit', source: candidate, publicationID: sourceData.publication_id,
      sourceFingerprint: sourceData.source_fingerprint, fields, catalogErrors: validation.errors };
  }
  if (kind === 'review') {
    const previewResult = await preview(validation.catalog, environment, dependencies);
    if ('view' in previewResult) return { ...previewResult, fields } as DashboardResult;
    return { view: 'review', source: validation.catalog, publicationID: sourceData.publication_id,
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
      return { view: 'success', publicationID: result.publication_id };
    } catch {
      return { view: 'error', status: 503, title: 'Publication result is uncertain', detail: 'The response was interrupted. The same reviewed publication can be retried safely; reload the catalog first to check whether it completed.', fields };
    }
  }
  return { view: 'edit', source: candidate, publicationID: sourceData.publication_id,
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
