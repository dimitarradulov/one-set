import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { cp, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { PGlite } from '@electric-sql/pglite';
import { exportSPKI, generateKeyPair, SignJWT } from 'jose';
import { handleCatalogRequest, type CatalogDatabase } from '../src/catalog.ts';
import { handleSetupRequest, type SetupDatabase } from '../src/setup.ts';
import { parse } from 'yaml';

const execute = promisify(execFile);
const issuer = 'https://clerk.test';
const signingKeys = await generateKeyPair('RS256', { extractable: true });
const environment = {
  CLERK_ISSUER: issuer,
  CLERK_JWT_KEY: await exportSPKI(signingKeys.publicKey),
  CLERK_AUTHORIZED_PARTIES: 'https://oneset.test',
  CATALOG_PUBLISH_TOKEN: 'e2e-publisher-secret',
};
const engine = new PGlite();
const database: CatalogDatabase = {
  query: async (sql, params = []) => (await engine.query<Record<string, unknown>>(sql, params)).rows,
  transaction: async (sql, params = []) => engine.transaction(async transaction =>
    (await transaction.query<Record<string, unknown>>(sql, params)).rows),
};

const schema = await readFile('../docs/database/migrations/001_documented_schema.sql', 'utf8');
await engine.exec('BEGIN;\n' + schema.slice(schema.indexOf('CREATE TYPE')));
await engine.exec(await readFile('../docs/database/migrations/002_completed_setup.sql', 'utf8'));
await engine.exec(`
  INSERT INTO workout_programs (id, name) VALUES
    (1, 'Full Body'), (2, 'Upper / Lower'), (3, 'Push / Pull / Legs'),
    (4, 'Bro Split'), (5, 'Minimalist Full Body'), (6, 'V-Taper'),
    (7, 'Powerhouse'), (8, 'Classic Physique'),
    (9, 'Free-Weight Full Body'), (10, 'Machine Full Body');
  INSERT INTO users (id, clerk_user_id, preferred_unit, training_days) VALUES (1, 'e2e-follower', 'kg', 3);
  INSERT INTO user_programs (id, user_id, workout_program_id, started_at)
    VALUES ('11111111-1111-4111-8111-111111111111', 1, 10, now());
  UPDATE users SET active_user_program_id = '11111111-1111-4111-8111-111111111111' WHERE id = 1;
  SELECT setval(pg_get_serial_sequence('workout_programs', 'id'), 10);
  SELECT setval(pg_get_serial_sequence('users', 'id'), 1);
`);
await engine.exec(await readFile('../docs/database/migrations/003_catalog_publication.sql', 'utf8'));

after(async () => { await engine.close(); });

test('founder preview and publish command persists the YAML catalog for authenticated app reads', async () => {
  const server = createServer(async (incoming, outgoing) => {
    try {
      const chunks: Buffer[] = [];
      for await (const chunk of incoming) chunks.push(Buffer.from(chunk));
      const payload = Buffer.concat(chunks);
      const request = new Request(`http://127.0.0.1${incoming.url ?? '/'}`, {
        method: incoming.method,
        headers: new Headers(incoming.headers as HeadersInit),
        ...(payload.length === 0 ? {} : { body: payload }),
      });
      const response = await handleCatalogRequest(request, environment, database);
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
  const reviewDirectory = await mkdtemp(join(tmpdir(), 'oneset-catalog-e2e-'));
  const reviewFile = join(reviewDirectory, 'review.json');
  const sourceDirectory = join(reviewDirectory, 'catalog');
  await cp('catalog', sourceDirectory, { recursive: true });
  await writeFile(join(sourceDirectory, 'programs', 'z-founder-authored-plan.yaml'), `key: founder-authored-plan
name: Founder Authored Plan
recommended_weeks: 6
training_days_per_week: 3
format: A / B / C
emphasis: A new plan added without an app or Worker configuration change.
workouts:
  - key: founder-authored-plan-a
    name: Workout A
    position: 1
    exercises:
      - key: founder-authored-plan-a-hack-squat
        exercise: hack-squat-machine
        position: 1
        reps: { minimum: 8, maximum: 12 }
        scope: reps
`);
  const cliEnvironment = {
    ...process.env,
    ONESET_CATALOG_API_E2E: `http://127.0.0.1:${address.port}`,
    ONESET_CATALOG_PUBLISH_TOKEN_E2E: environment.CATALOG_PUBLISH_TOKEN,
  };

  try {
    const preview = await execute(process.execPath, [
      '--import', 'tsx', 'scripts/catalog.ts', 'preview', '--environment', 'e2e',
      '--source', sourceDirectory, '--preview-file', reviewFile,
    ], { cwd: process.cwd(), env: cliEnvironment });
    assert.match(preview.stdout, /Preview for e2e/);
    assert.match(preview.stdout, /Machine Full Body/);

    const publication = await execute(process.execPath, [
      '--import', 'tsx', 'scripts/catalog.ts', 'publish', '--environment', 'e2e',
      '--source', sourceDirectory, '--preview-file', reviewFile,
    ], { cwd: process.cwd(), env: cliEnvironment });
    assert.match(publication.stdout, /Published catalog to e2e:/);

    const userToken = await new SignJWT({ sid: 'e2e-session' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setSubject('e2e-follower')
      .setIssuer(issuer).setIssuedAt().setNotBefore('0s').setExpirationTime('1m')
      .sign(signingKeys.privateKey);
    const response = await fetch(`http://127.0.0.1:${address.port}/v1/catalog`, {
      headers: { Authorization: `Bearer ${userToken}` },
    });
    assert.equal(response.status, 200);
    const result = await response.json() as {
      catalog: {
        programs: Array<{ key: string; recommended_weeks: number; workouts: Array<{ key: string }> }>;
        exercises: Array<{ key: string; instructions: string; stopping_guidance: string; warmup_guidance: string }>;
      };
    };
    const sourceExercises = parse(await readFile(join(sourceDirectory, 'exercises.yaml'), 'utf8')) as { exercises: unknown[] };
    const sourcePrograms = (await readdir(join(sourceDirectory, 'programs')))
      .filter(file => file.endsWith('.yaml')).sort();
    const expectedCatalog = {
      exercises: sourceExercises.exercises,
      programs: await Promise.all(sourcePrograms.map(async file =>
        parse(await readFile(join(sourceDirectory, 'programs', file), 'utf8')))),
    };
    assert.deepEqual(result.catalog, expectedCatalog);
    assert.equal(result.catalog.programs.length, 11);
    const machineProgram = result.catalog.programs.find(program => program.key === 'machine-full-body');
    assert.equal(machineProgram?.recommended_weeks, 8);
    assert.equal(machineProgram?.workouts.length, 3);
    assert.equal(result.catalog.exercises.length, 47);
    const hackSquat = result.catalog.exercises.find(exercise => exercise.key === 'hack-squat-machine');
    assert.equal(typeof hackSquat?.instructions, 'string');
    assert.equal(typeof hackSquat?.stopping_guidance, 'string');
    assert.equal(typeof hackSquat?.warmup_guidance, 'string');
    assert.equal(result.catalog.programs.some(program => program.key === 'founder-authored-plan'), true);

    const newUserToken = await new SignJWT({ sid: 'e2e-new-user-session' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setSubject('e2e-new-user')
      .setIssuer(issuer).setIssuedAt().setNotBefore('0s').setExpirationTime('1m')
      .sign(signingKeys.privateKey);
    const newSetup = {
      preferred_unit: 'kg', training_days: 3, program_id: 'founder-authored-plan',
      cycle_id: '22222222-2222-4222-8222-222222222222',
    };
    const setupDatabase: SetupDatabase = { query: database.query };
    const saved = await handleSetupRequest(new Request('https://api.oneset.test/v1/me/setup', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${newUserToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(newSetup),
    }), environment, setupDatabase);
    assert.equal(saved.status, 200, JSON.stringify(await saved.clone().json()));
    assert.deepEqual(await saved.json(), { setup: newSetup });
    const restored = await handleSetupRequest(new Request('https://api.oneset.test/v1/me/setup', {
      headers: { Authorization: `Bearer ${newUserToken}` },
    }), environment, setupDatabase);
    assert.deepEqual(await restored.json(), { setup: newSetup });

    const preserved = await database.query(`SELECT program.id, users.active_user_program_id
      FROM workout_programs program JOIN user_programs cycle ON cycle.workout_program_id = program.id
      JOIN users ON users.id = cycle.user_id WHERE program.authoring_key = 'machine-full-body'`);
    assert.deepEqual(preserved, [{ id: 10, active_user_program_id: '11111111-1111-4111-8111-111111111111' }]);
  } finally {
    server.close();
    await once(server, 'close');
    await rm(reviewDirectory, { recursive: true, force: true });
  }
});
