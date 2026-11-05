import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { access, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { PGlite } from '@electric-sql/pglite';
import { generateKeyPair, SignJWT, type JWTVerifyGetKey } from 'jose';
import { parse } from 'yaml';
import { handleDashboardRequest, type DashboardEnvironment } from '../src/dashboard.ts';
import { handleCatalogRequest, type CatalogDatabase } from '../../worker/src/catalog.ts';
import type { CatalogSource } from '../../worker/src/catalog-validation.ts';

const founder = 'founder@example.test';
const audience = 'dashboard-request-test';
const keys = await generateKeyPair('RS256', { extractable: true });
const keySource: JWTVerifyGetKey = async () => keys.publicKey;
const environment: DashboardEnvironment = {
  ACCESS_TEAM_DOMAIN: 'https://oneset-test.cloudflareaccess.com',
  ACCESS_AUDIENCE: audience,
  ACCESS_APPROVED_EMAIL: founder,
  CATALOG_ENVIRONMENT: 'integration',
  CATALOG_API_BASE_URL: '',
};
let storageUnavailable = false;
const exercisesDoc = parse(await readFile(new URL('../../worker/catalog/exercises.yaml', import.meta.url), 'utf8')) as { exercises: CatalogSource['exercises'] };
const programFiles = (await readdir(new URL('../../worker/catalog/programs/', import.meta.url)))
  .filter(name => name.endsWith('.yaml')).sort();
const source: CatalogSource = {
  exercises: exercisesDoc.exercises,
  programs: await Promise.all(programFiles.map(async name => parse(await readFile(
    join(new URL('../../worker/catalog/programs/', import.meta.url).pathname, name), 'utf8')) as CatalogSource['programs'][number])),
};
source.programs[0]!.removed = true;
source.programs[0]!.workouts[0]!.removed = true;
source.programs[0]!.workouts[0]!.exercises[0]!.removed = true;
source.programs[0]!.workouts.slice(1).forEach((workout, index) => { workout.position = index + 1; });
source.programs[0]!.workouts[0]!.exercises.slice(1).forEach((slot, index) => { slot.position = index + 1; });
const engine = new PGlite();
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
  query: async () => {
    if (storageUnavailable) throw new Error('simulated storage outage');
    return (await engine.query<Record<string, unknown>>(`SELECT publication_id, source_fingerprint, source_document
      FROM public.catalog_state WHERE singleton = true`)).rows;
  },
  transaction: async (sql, params = []) => engine.transaction(async transaction =>
    (await transaction.query<Record<string, unknown>>(sql, params)).rows),
};
let api: ReturnType<typeof createServer> | undefined;
let apiOrigin = '';

async function token(email = founder): Promise<string> {
  return new SignJWT({ email })
    .setProtectedHeader({ alg: 'RS256', kid: 'dashboard-request-test' })
    .setIssuer(environment.ACCESS_TEAM_DOMAIN).setAudience(audience)
    .setIssuedAt().setExpirationTime('2m').sign(keys.privateKey);
}

after(async () => {
  if (api?.listening) {
    api.close();
    await once(api, 'close');
  }
  await engine.close();
});

test('request renders complete catalog through the protected source-read boundary', async () => {
  api = createServer(async (incoming, outgoing) => {
    try {
      const chunks: Buffer[] = [];
      for await (const chunk of incoming) chunks.push(Buffer.from(chunk));
      const body = Buffer.concat(chunks);
      const request = new Request(`${apiOrigin}${incoming.url ?? '/'}`, {
        method: incoming.method,
        headers: new Headers(incoming.headers as HeadersInit),
        ...(body.length ? { body } : {}),
      });
      const response = await handleCatalogRequest(request, {
        CLERK_ISSUER: 'https://clerk.test', CLERK_JWT_KEY: '', CLERK_AUTHORIZED_PARTIES: '',
        CATALOG_PUBLISH_TOKEN: '', ACCESS_TEAM_DOMAIN: environment.ACCESS_TEAM_DOMAIN,
        ACCESS_AUDIENCE: audience, ACCESS_APPROVED_EMAIL: founder,
      }, database, keySource);
      outgoing.writeHead(response.status, Object.fromEntries(response.headers.entries()));
      outgoing.end(await response.text());
    } catch {
      outgoing.writeHead(500);
      outgoing.end();
    }
  });
  api.listen(0, '127.0.0.1');
  await once(api, 'listening');
  const address = api.address();
  assert.ok(address && typeof address === 'object');
  apiOrigin = `http://127.0.0.1:${address.port}`;
  environment.CATALOG_API_BASE_URL = apiOrigin;

  const browserRequest = new Request('https://dashboard.test/', {
    headers: { 'Cf-Access-Jwt-Assertion': await token() },
  });
  const rendered = await handleDashboardRequest(browserRequest, environment, {
    keySource,
    fetcher: fetch,
  });
  assert.equal(rendered.status, 200);
  const html = await rendered.text();
  assert.match(html, /Full Body/);
  assert.match(html, /Weighted Chin-Up/);
  assert.match(html, /Lower the weight under control/);
  assert.match(html, /Removed/);
  assert.match(html, /publication-request-test/);
  assert.match(html, /10 programs/);
  assert.match(html, /47 shared exercises/);
  assert.match(html, /Environment <strong>integration<\/strong>/);
  assert.match(rendered.headers.get('Cache-Control') ?? '', /no-store/);

  const screenshotPath = process.env.DASHBOARD_SCREENSHOT_PATH;
  if (screenshotPath) {
    const chromePath = process.env.DASHBOARD_CHROME_BIN
      ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
    await access(chromePath);
    const css = await readFile(new URL('../public/dashboard.css', import.meta.url), 'utf8');
    const previewPath = `${screenshotPath}.html`;
    const expandedCatalog = html.replace('<details class="program">', '<details class="program" open>');
    await writeFile(previewPath, expandedCatalog.replace('<link rel="stylesheet" href="/dashboard.css">', `<style>${css}</style>`));
    const browser = spawn(chromePath, [
      '--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
      '--window-size=1440,1200', `--screenshot=${screenshotPath}`, `file://${previewPath}`,
    ], { stdio: 'ignore' });
    const [code] = await once(browser, 'exit') as [number | null];
    assert.equal(code, 0, 'Chrome should capture the rendered dashboard');
  }

  const unauthorized = await handleDashboardRequest(new Request('https://dashboard.test/'), environment, { keySource });
  assert.equal(unauthorized.status, 401);
  assert.match(await unauthorized.text(), /Access required/);

  const mutation = await handleDashboardRequest(new Request('https://dashboard.test/', { method: 'POST' }), environment, { keySource });
  assert.equal(mutation.status, 405);

  const wrongIdentity = await handleDashboardRequest(new Request('https://dashboard.test/', {
    headers: { 'Cf-Access-Jwt-Assertion': await token('intruder@example.test') },
  }), environment, { keySource });
  assert.equal(wrongIdentity.status, 401);

  storageUnavailable = true;
  const unavailable = await handleDashboardRequest(browserRequest, environment, { keySource, fetcher: fetch });
  assert.equal(unavailable.status, 503);
  assert.match(await unavailable.text(), /Catalog storage is unavailable/);
});
