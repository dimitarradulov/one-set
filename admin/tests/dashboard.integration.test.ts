import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { access } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import net from 'node:net';
import { PGlite } from '@electric-sql/pglite';
import { exportJWK, exportSPKI, generateKeyPair, SignJWT, type JWTVerifyGetKey } from 'jose';
import { chromium } from 'playwright-core';
import { parse } from 'yaml';
import { handleDashboardAction, loadDashboard, renderDashboard, type DashboardEnvironment, type DashboardResult, type ProgramFields } from '../src/dashboard.ts';
import { handleCatalogRequest, type CatalogDatabase, type CatalogConfiguration } from '../../worker/src/catalog.ts';
import { verifyCloudflareAccess } from '../../worker/src/cloudflare-access.ts';
import type { CatalogSource } from '../../worker/src/catalog-validation.ts';

const founder = 'founder@example.test';
const team = 'https://oneset-test.cloudflareaccess.com';
const audience = 'dashboard-request-test';
const publisherToken = 'test-publisher-token';
const accessKeys = await generateKeyPair('RS256', { extractable: true });
const accessKeySource: JWTVerifyGetKey = async () => accessKeys.publicKey;
const accessJWK = { ...(await exportJWK(accessKeys.publicKey)), kid: 'dashboard-request-test', alg: 'RS256', use: 'sig' };
const clerkKeys = await generateKeyPair('RS256', { extractable: true });
const apiEnvironment: CatalogConfiguration = {
  CLERK_ISSUER: 'https://clerk.integration.test',
  CLERK_JWT_KEY: await exportSPKI(clerkKeys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://app.integration.test',
  CATALOG_PUBLISH_TOKEN: publisherToken,
  ACCESS_TEAM_DOMAIN: team,
  ACCESS_AUDIENCE: audience,
  ACCESS_APPROVED_EMAIL: founder,
};
const environment: DashboardEnvironment = {
  ACCESS_TEAM_DOMAIN: team,
  ACCESS_AUDIENCE: audience,
  ACCESS_APPROVED_EMAIL: founder,
  CATALOG_ENVIRONMENT: 'development',
  CATALOG_API_BASE_URL: '',
  CATALOG_PUBLISH_TOKEN: publisherToken,
};
let transactionFailure = false;
let server: ReturnType<typeof createServer> | undefined;
let apiOrigin = '';
const engine = new PGlite();
const exercisesDoc = parse(await readFile(new URL('../../worker/catalog/exercises.yaml', import.meta.url), 'utf8')) as { exercises: CatalogSource['exercises'] };
const programFiles = (await readdir(new URL('../../worker/catalog/programs/', import.meta.url)))
  .filter(name => name.endsWith('.yaml')).sort();
const source: CatalogSource = {
  exercises: exercisesDoc.exercises,
  programs: await Promise.all(programFiles.map(async name => parse(await readFile(
    join(new URL('../../worker/catalog/programs/', import.meta.url).pathname, name), 'utf8')) as CatalogSource['programs'][number])),
};
source.release_note = 'Metadata from a future authoring tool';
source.programs[0]!.editor_hint = { preserve: true };
source.programs[0]!.removed = true;
source.programs[0]!.workouts[0]!.removed = true;
source.programs[0]!.workouts[0]!.exercises[0]!.removed = true;
source.programs[0]!.workouts.slice(1).forEach((workout, index) => { workout.position = index + 1; });
source.programs[0]!.workouts[0]!.exercises.slice(1).forEach((slot, index) => { slot.position = index + 1; });

const initialSchema = await readFile(new URL('../../docs/database/migrations/001_documented_schema.sql', import.meta.url), 'utf8');
await engine.exec(`BEGIN;\n${initialSchema.slice(initialSchema.indexOf('CREATE TYPE'))}`);
await engine.exec(await readFile(new URL('../../docs/database/migrations/002_completed_setup.sql', import.meta.url), 'utf8'));
await engine.exec(await readFile(new URL('../../docs/database/migrations/003_catalog_publication.sql', import.meta.url), 'utf8'));
const fingerprint = 'b'.repeat(64);
await engine.query(`INSERT INTO public.catalog_publications (id, source_fingerprint, backend_fingerprint, source_document)
  VALUES ($1, $2, 'empty', $3::jsonb)`, ['publication-request-test', fingerprint, JSON.stringify(source)]);
await engine.query(`UPDATE public.catalog_state SET publication_id = $1, source_fingerprint = $2, source_document = $3::jsonb
  WHERE singleton = true`, ['publication-request-test', fingerprint, JSON.stringify(source)]);
const database: CatalogDatabase = {
  query: async (sql, params = []) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
  transaction: async (sql, params = []) => {
    if (transactionFailure) throw new Error('simulated transaction failure');
    return engine.transaction(async transaction => (await transaction.query<Record<string, unknown>>(sql, params)).rows);
  },
};

async function token(email = founder, issuer = team): Promise<string> {
  return new SignJWT({ email })
    .setProtectedHeader({ alg: 'RS256', kid: 'dashboard-request-test' })
    .setIssuer(issuer).setAudience(audience).setIssuedAt().setExpirationTime('2m').sign(accessKeys.privateKey);
}

async function clerkToken(): Promise<string> {
  return new SignJWT({ sid: 'session-integration', azp: 'https://app.integration.test', sts: 'active' })
    .setProtectedHeader({ alg: 'RS256' }).setIssuer(apiEnvironment.CLERK_ISSUER)
    .setSubject('user_integration').setIssuedAt().setExpirationTime('2m').sign(clerkKeys.privateKey);
}

function form(fields: Partial<ProgramFields> & Record<string, string> = {}): FormData {
  const values: Record<string, string> = {
    program_key: source.programs[1]!.key,
    name: 'Upper / Lower Updated',
    format: '4 workouts · Upper / Lower',
    emphasis: 'Balanced strength with a tested emphasis.',
    recommended_weeks: '14',
    ...fields,
  };
  const result = new FormData();
  for (const [key, value] of Object.entries(values)) result.set(key, value);
  return result;
}

async function dashboardRequest(action: string, fields: FormData, accessToken?: string, origin = 'https://dashboard.test', submittedOrigin = origin) {
  const body = new URLSearchParams();
  for (const [key, value] of fields.entries()) body.append(key, String(value));
  return new Request(`${origin}/?_action=${action}`, {
    method: 'POST',
    headers: {
      Origin: submittedOrigin,
      'Sec-Fetch-Site': 'same-origin',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cf-Access-Jwt-Assertion': accessToken ?? await token(),
    },
    body,
  });
}

async function publishFields(review: Extract<DashboardResult, { view: 'review' }>): Promise<FormData> {
  const published = { ...review.source, programs: review.source.programs.map(program => program.key === review.fields.program_key ? {
    ...program, name: review.fields.name, format: review.fields.format, emphasis: review.fields.emphasis,
    recommended_weeks: Number(review.fields.recommended_weeks),
  } : program) };
  const { createHash } = await import('node:crypto');
  const sourceFingerprint = createHash('sha256').update(JSON.stringify(published)).digest('hex');
  return form({ ...review.fields, publication_fingerprint: review.sourceFingerprint,
    source_fingerprint: sourceFingerprint, preview_id: review.previewID, backend_fingerprint: review.backendFingerprint });
}

async function readCurrentSource(): Promise<SourceResponse> {
  const rows = await database.query(`SELECT publication_id, source_fingerprint, source_document FROM public.catalog_state WHERE singleton = true`);
  const row = rows[0]!;
  return { publication_id: String(row.publication_id), source_fingerprint: String(row.source_fingerprint), source: row.source_document as CatalogSource };
}

interface SourceResponse { source: CatalogSource; publication_id: string; source_fingerprint: string }

server = createServer(async (incoming, outgoing) => {
  try {
    const chunks: Buffer[] = [];
    for await (const chunk of incoming) chunks.push(Buffer.from(chunk));
    const body = Buffer.concat(chunks);
    const request = new Request(`${apiOrigin}${incoming.url ?? '/'}`, {
      method: incoming.method,
      headers: new Headers(incoming.headers as HeadersInit),
      ...(body.length ? { body } : {}),
    });
    if (new URL(request.url).pathname === '/cdn-cgi/access/certs') {
      outgoing.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=60' });
      outgoing.end(JSON.stringify({ keys: [accessJWK] }));
      return;
    }
    const response = await handleCatalogRequest(request, apiEnvironment, database, accessKeySource);
    outgoing.writeHead(response.status, Object.fromEntries(response.headers.entries()));
    outgoing.end(await response.text());
  } catch {
    outgoing.writeHead(500);
    outgoing.end();
  }
});
server.listen(0, '127.0.0.1');
await once(server, 'listening');
const address = server.address();
assert.ok(address && typeof address === 'object');
apiOrigin = `http://127.0.0.1:${address.port}`;
environment.CATALOG_API_BASE_URL = apiOrigin;

after(async () => {
  if (server?.listening) { server.close(); await once(server, 'close'); }
  await engine.close();
});

test('protected edit → review → edit → publish → app catalog keeps unknown metadata, removed identities, and state', async () => {
  const accessToken = await token();
  const get = new Request('https://dashboard.test/', { headers: { 'Cf-Access-Jwt-Assertion': accessToken } });
  const loaded = await loadDashboard(get, environment, { keySource: accessKeySource });
  assert.equal(loaded.source?.source.programs.length, 10);
  assert.ok(loaded.source?.source.programs[0]?.removed);
  const initialHTML = renderDashboard(undefined, loaded.source, environment);
  assert.match(initialHTML, /action="@editProgram"/);
  assert.match(initialHTML, /Edit details/);
  assert.match(initialHTML, /Removed/);
  assert.match(initialHTML, /Browse workout templates and shared exercises/);
  assert.match(initialHTML, /Weighted Chin-Up/);
  assert.doesNotMatch(initialHTML, /localStorage|autosave|test-publisher-token/i);

  const selected = source.programs[1]!;
  const invalid = form({ program_key: selected.key, name: '   ', publication_fingerprint: loaded.source!.source_fingerprint });
  const invalidResult = await handleDashboardAction('review', await dashboardRequest('reviewProgram', invalid, accessToken), invalid,
    environment, { keySource: accessKeySource });
  assert.equal(invalidResult.view, 'edit');
  if (invalidResult.view === 'edit') assert.equal(invalidResult.errors?.name, 'Enter a program name.');

  const edited = form({ program_key: selected.key, publication_fingerprint: loaded.source!.source_fingerprint });
  const editResult = await handleDashboardAction('edit', await dashboardRequest('editProgram', edited, accessToken), edited,
    environment, { keySource: accessKeySource });
  assert.equal(editResult.view, 'edit');
  if (editResult.view === 'edit') assert.equal(editResult.fields.name, 'Upper / Lower Updated');

  const reviewForm = form({ program_key: selected.key, publication_fingerprint: loaded.source!.source_fingerprint });
  const reviewResult = await handleDashboardAction('review', await dashboardRequest('reviewProgram', reviewForm, accessToken), reviewForm,
    environment, { keySource: accessKeySource });
  assert.equal(reviewResult.view, 'review');
  if (reviewResult.view !== 'review') return;
  assert.ok(reviewResult.changes.length > 0);
  assert.ok(reviewResult.affectedPrograms.some(item => item.includes(selected.key)));
  assert.equal((await readCurrentSource()).source.programs[1]!.name, selected.name, 'review must not mutate published source');

  const returnedToEdit = await handleDashboardAction('edit', await dashboardRequest('editProgram', reviewForm, accessToken), reviewForm,
    environment, { keySource: accessKeySource });
  assert.equal(returnedToEdit.view, 'edit');
  if (returnedToEdit.view === 'edit') assert.equal(returnedToEdit.fields.emphasis, 'Balanced strength with a tested emphasis.');

  const exactReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', reviewForm, accessToken), reviewForm,
    environment, { keySource: accessKeySource });
  assert.equal(exactReview.view, 'review');
  if (exactReview.view !== 'review') return;
  const submitted = await publishFields(exactReview);
  const published = await handleDashboardAction('publish', await dashboardRequest('publishProgram', submitted, accessToken), submitted,
    environment, { keySource: accessKeySource });
  assert.equal(published.view, 'success');
  const current = await readCurrentSource();
  assert.equal(current.source.programs[1]!.name, 'Upper / Lower Updated');
  assert.equal(current.source.programs[1]!.format, '4 workouts · Upper / Lower');
  assert.deepEqual(current.source.programs[0]!.editor_hint, { preserve: true });
  assert.equal(current.source.release_note, 'Metadata from a future authoring tool');
  assert.equal(current.source.programs[0]!.removed, true);
  assert.equal(current.source.programs[0]!.workouts[0]!.removed, true);
  assert.equal(current.source.programs[0]!.workouts[0]!.exercises[0]!.removed, true);

  const appCatalog = await handleCatalogRequest(new Request(`${apiOrigin}/v1/catalog`, {
    headers: { Authorization: `Bearer ${await clerkToken()}` },
  }), apiEnvironment, database, accessKeySource);
  assert.equal(appCatalog.status, 200);
  const catalog = await appCatalog.json() as { catalog: CatalogSource };
  assert.equal(catalog.catalog.programs.find(program => program.key === selected.key)?.name, 'Upper / Lower Updated');
  assert.equal(catalog.catalog.programs.find(program => program.key === source.programs[0]!.key)?.removed, true,
    'removed program identity remains available to current followers with its unavailable marker');
});

test('direct, cross-origin, and wrong-identity actions cannot reach the publisher', async () => {
  const fields = form({ publication_fingerprint: (await readCurrentSource()).source_fingerprint });
  const noToken = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, ''), fields,
    environment, { keySource: accessKeySource });
  assert.equal(noToken.view, 'error');
  if (noToken.view === 'error') assert.equal(noToken.status, 401);
  const wrongOrigin = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, await token(), 'https://dashboard.test', 'https://attacker.test'), fields,
    environment, { keySource: accessKeySource });
  assert.equal(wrongOrigin.view, 'error');
  if (wrongOrigin.view === 'error') assert.equal(wrongOrigin.status, 401);
  const wrongIdentity = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, await token('intruder@example.test')), fields,
    environment, { keySource: accessKeySource });
  assert.equal(wrongIdentity.view, 'error');
  if (wrongIdentity.view === 'error') assert.equal(wrongIdentity.status, 401);
});

test('non-development targets stay read-only even for the approved founder', async () => {
  const production = { ...environment, CATALOG_ENVIRONMENT: 'production' };
  const loaded = await loadDashboard(new Request('https://dashboard.test/', {
    headers: { 'Cf-Access-Jwt-Assertion': await token() },
  }), production, { keySource: accessKeySource });
  assert.ok(loaded.source);
  const html = renderDashboard(undefined, loaded.source, production);
  assert.doesNotMatch(html, /Edit details|action="@editProgram"/);
  assert.match(html, /Editing and publication are disabled/);
  const submitted = form({ publication_fingerprint: loaded.source!.source_fingerprint });
  const result = await handleDashboardAction('review', await dashboardRequest('reviewProgram', submitted), submitted,
    production, { keySource: accessKeySource });
  assert.equal(result.view, 'error');
  if (result.view === 'error') assert.equal(result.status, 403);
});

test('stale reviews and transaction failures report errors and preserve the previous catalog', async () => {
  const accessToken = await token();
  const baseline = await readCurrentSource();
  const fields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'Stale Candidate' });
  const review = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, accessToken), fields,
    environment, { keySource: accessKeySource });
  assert.equal(review.view, 'review');
  if (review.view !== 'review') return;

  const competitorFields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'CLI Candidate' });
  const competitorReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', competitorFields, accessToken), competitorFields,
    environment, { keySource: accessKeySource });
  assert.equal(competitorReview.view, 'review');
  if (competitorReview.view !== 'review') return;
  const competitorPublishForm = await publishFields(competitorReview);
  const competitorPublished = await handleDashboardAction('publish', await dashboardRequest('publishProgram', competitorPublishForm, accessToken), competitorPublishForm,
    environment, { keySource: accessKeySource });
  assert.equal(competitorPublished.view, 'success');

  const staleForm = await publishFields(review);
  const stale = await handleDashboardAction('publish', await dashboardRequest('publishProgram', staleForm, accessToken), staleForm,
    environment, { keySource: accessKeySource });
  assert.equal(stale.view, 'error');
  if (stale.view === 'error') assert.equal(stale.status, 409);

  const latest = await readCurrentSource();
  const rollbackFields = form({ publication_fingerprint: latest.source_fingerprint, name: 'Rolled Back Candidate' });
  const rollbackReview = await handleDashboardAction('review', await dashboardRequest('reviewProgram', rollbackFields, accessToken), rollbackFields,
    environment, { keySource: accessKeySource });
  assert.equal(rollbackReview.view, 'review');
  if (rollbackReview.view !== 'review') return;
  transactionFailure = true;
  const rollbackForm = await publishFields(rollbackReview);
  const failed = await handleDashboardAction('publish', await dashboardRequest('publishProgram', rollbackForm, accessToken), rollbackForm,
    environment, { keySource: accessKeySource });
  transactionFailure = false;
  assert.equal(failed.view, 'error');
  if (failed.view === 'error') assert.equal(failed.status, 503);
  assert.equal((await readCurrentSource()).source.programs[1]!.name, 'CLI Candidate');
});

test('same reviewed publish retry is idempotent after the dashboard loses the first response', async () => {
  const accessToken = await token();
  const baseline = await readCurrentSource();
  const fields = form({ publication_fingerprint: baseline.source_fingerprint, name: 'Retry Candidate' });
  const review = await handleDashboardAction('review', await dashboardRequest('reviewProgram', fields, accessToken), fields,
    environment, { keySource: accessKeySource });
  assert.equal(review.view, 'review');
  if (review.view !== 'review') return;
  const retryForm = await publishFields(review);
  const before = await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  const uncertain = await handleDashboardAction('publish', await dashboardRequest('publishProgram', retryForm, accessToken), retryForm,
    environment, {
      keySource: accessKeySource,
      fetcher: async (input, init) => {
        const response = await fetch(input, init);
        if (new URL(String(input)).pathname.endsWith('/publish')) throw new Error('simulated lost response after commit');
        return response;
      },
    });
  assert.equal(uncertain.view, 'error');
  if (uncertain.view === 'error') assert.equal(uncertain.status, 503);
  const retry = await handleDashboardAction('publish', await dashboardRequest('publishProgram', retryForm, accessToken), retryForm,
    environment, { keySource: accessKeySource });
  assert.equal(retry.view, 'success');
  const afterRetry = await engine.query<{ count: string }>(`SELECT count(*)::text AS count FROM public.catalog_publications`);
  assert.equal(Number(afterRetry.rows[0]?.count), Number(before.rows[0]?.count) + 1,
    'the uncertain first request creates one publication and the identical retry reuses it');
  assert.equal((await readCurrentSource()).source.programs[1]!.name, 'Retry Candidate');
});

test('visual artifacts can be captured for edit, review, success, and error states', async () => {
  const outputDirectory = process.env.DASHBOARD_SCREENSHOT_DIR;
  if (!outputDirectory) return;
  const chromePath = process.env.DASHBOARD_CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  await access(chromePath);
  await mkdir(outputDirectory, { recursive: true });
  const loaded = await loadDashboard(new Request('https://dashboard.test/', { headers: { 'Cf-Access-Jwt-Assertion': await token() } }),
    environment, { keySource: accessKeySource });
  assert.ok(loaded.source);
  const selected = loaded.source!.source.programs[1]!;
  const fields: ProgramFields = { program_key: selected.key, name: 'A considered program name', format: selected.format,
    emphasis: selected.emphasis, recommended_weeks: String(selected.recommended_weeks) };
  const edit: DashboardResult = { view: 'edit', source: loaded.source!.source, publicationID: loaded.source!.publication_id,
    sourceFingerprint: loaded.source!.source_fingerprint, fields };
  const reviewRequest = form({ ...fields, publication_fingerprint: loaded.source!.source_fingerprint });
  const reviewed = await handleDashboardAction('review', await dashboardRequest('reviewProgram', reviewRequest), reviewRequest,
    environment, { keySource: accessKeySource });
  assert.equal(reviewed.view, 'review');
  const success: DashboardResult = { view: 'success', publicationID: 'publication-success-preview' };
  const error: DashboardResult = { view: 'error', status: 503, title: 'Catalog service unavailable', detail: 'The catalog service could not prepare a review. Retry when the service is available.' };
  const states: Array<[string, DashboardResult | undefined, SourceResponse | undefined]> = [
    ['catalog', undefined, loaded.source],
    ['edit', edit, undefined], ['review', reviewed as DashboardResult, undefined], ['success', success, undefined], ['error', error, undefined],
  ];
  const css = await readFile(new URL('../public/dashboard.css', import.meta.url), 'utf8');
  for (const [name, state, sourceData] of states) {
    const html = renderDashboard(state, sourceData, environment).replace('<link rel="stylesheet" href="/dashboard.css">', `<style>${css}</style>`)
      .replaceAll('action="@editProgram"', 'action="#"').replaceAll('action="@reviewProgram"', 'action="#"').replaceAll('action="@publishProgram"', 'action="#"');
    const imagePath = resolve(outputDirectory, `issue-60-${name}.png`);
    const htmlPath = `${imagePath}.html`;
    await (await import('node:fs/promises')).writeFile(htmlPath, html);
    const browser = spawn(chromePath, ['--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
      '--window-size=1440,1100', `--screenshot=${imagePath}`, `file://${htmlPath}`], { stdio: 'ignore' });
    const [code] = await once(browser, 'exit') as [number | null];
    assert.equal(code, 0, `Chrome should capture ${name} state`);
  }
});

test('real browser submits native Astro Action forms through edit → review → edit → publish', { timeout: 90_000 }, async t => {
  const chromePath = process.env.DASHBOARD_CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  try { await access(chromePath); } catch { t.skip('Set DASHBOARD_CHROME_BIN to run the local browser journey'); return; }
  const outputDirectory = process.env.DASHBOARD_SCREENSHOT_DIR;
  if (outputDirectory) await mkdir(outputDirectory, { recursive: true });
  const portServer = net.createServer();
  portServer.listen(0, '127.0.0.1');
  await once(portServer, 'listening');
  const browserPort = (portServer.address() as net.AddressInfo).port;
  await new Promise<void>((resolveClose, rejectClose) => portServer.close(error => error ? rejectClose(error) : resolveClose()));

  const baseConfigPath = new URL('../dist/server/wrangler.json', import.meta.url);
  const config = JSON.parse(await readFile(baseConfigPath, 'utf8')) as { name: string; compatibility_date: string; vars: Record<string, string> };
  config.name = 'oneset-catalog-dashboard-browser-test';
  config.compatibility_date = '2026-10-08';
  environment.ACCESS_TEAM_DOMAIN = apiOrigin;
  apiEnvironment.ACCESS_TEAM_DOMAIN = apiOrigin;
  config.vars = {
    CATALOG_ENVIRONMENT: 'development',
    CATALOG_API_BASE_URL: apiOrigin,
    CATALOG_PUBLISH_TOKEN: publisherToken,
    ACCESS_TEAM_DOMAIN: apiOrigin,
    ACCESS_AUDIENCE: audience,
    ACCESS_APPROVED_EMAIL: founder,
  };
  const e2eConfigPath = new URL('../dist/server/wrangler.e2e.json', import.meta.url);
  await writeFile(e2eConfigPath, JSON.stringify(config));
  const wranglerPath = resolve(new URL('../../worker/node_modules/.bin/wrangler', import.meta.url).pathname);
  const worker = spawn(wranglerPath, ['dev', '--config', e2eConfigPath.pathname, '--port', String(browserPort), '--ip', '127.0.0.1', '--local'], { stdio: 'ignore' });
  const workerExit = once(worker, 'exit');
  let browser: Awaited<ReturnType<typeof chromium.launch>> | undefined;
  try {
    const origin = `http://127.0.0.1:${browserPort}`;
    let ready = false;
    for (let attempt = 0; attempt < 60; attempt++) {
      try {
        const response = await fetch(origin);
        if (response.status === 401 || response.status === 200) { ready = true; break; }
      } catch { /* Wrangler is still starting. */ }
      await new Promise(resolveWait => setTimeout(resolveWait, 250));
    }
    assert.ok(ready, 'Astro Worker should become ready');
    const browserToken = await token(founder, apiOrigin);
    assert.equal(await verifyCloudflareAccess(new Request('https://dashboard.test/', {
      headers: { 'Cf-Access-Jwt-Assertion': browserToken },
    }), { ACCESS_TEAM_DOMAIN: apiOrigin, ACCESS_AUDIENCE: audience, ACCESS_APPROVED_EMAIL: founder }), true,
    'the local signed Access token should verify against the local cert endpoint');
    browser = await chromium.launch({ executablePath: chromePath, headless: true, args: ['--no-sandbox'] });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
    await page.setExtraHTTPHeaders({ 'Cf-Access-Jwt-Assertion': browserToken });
    const response = await page.goto(`${origin}/`, { waitUntil: 'networkidle' });
    assert.equal(response?.status(), 200);
    await page.getByRole('button', { name: 'Edit details' }).nth(1).click();
    await page.getByLabel('Program name').waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-60-browser-edit.png'), fullPage: true });

    await page.getByLabel('Program name').evaluate(input => input.removeAttribute('required'));
    await page.getByLabel('Program name').fill('');
    await page.getByRole('button', { name: 'Review changes' }).click();
    const validationText = await page.locator('body').innerText();
    assert.match(validationText, /Enter a program name\./, `server validation should return the edit form; received: ${validationText}`);
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-60-browser-error.png'), fullPage: true });

    await page.getByLabel('Program name').fill('Browser action roundtrip');
    await page.getByLabel('Emphasis').fill('A browser-verified program detail change.');
    await page.getByRole('button', { name: 'Review changes' }).click();
    await page.getByRole('heading', { name: 'Review program changes' }).waitFor();
    await page.getByText('A browser-verified program detail change.').waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-60-browser-review.png'), fullPage: true });

    await page.getByRole('button', { name: 'Back to editing' }).click();
    await page.getByLabel('Program name').waitFor();
    assert.equal(await page.getByLabel('Program name').inputValue(), 'Browser action roundtrip');
    await page.getByLabel('Program name').fill('Browser publication complete');
    await page.getByRole('button', { name: 'Review changes' }).click();
    await page.getByRole('heading', { name: 'Review program changes' }).waitFor();
    await page.getByRole('button', { name: 'Publish to development' }).click();
    await page.getByRole('heading', { name: 'Catalog published' }).waitFor();
    if (outputDirectory) await page.screenshot({ path: resolve(outputDirectory, 'issue-60-browser-success.png'), fullPage: true });
    assert.equal((await readCurrentSource()).source.programs[1]!.name, 'Browser publication complete');
  } finally {
    await browser?.close();
    worker.kill('SIGTERM');
    await workerExit.catch(() => undefined);
    await (await import('node:fs/promises')).unlink(e2eConfigPath.pathname).catch(() => undefined);
  }
});
