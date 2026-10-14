import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

const execute = promisify(execFile);

test('preview validates authored YAML and prints the backend change for its explicit environment', async () => {
  const root = await mkdtemp(join(tmpdir(), 'oneset-catalog-preview-'));
  const source = join(root, 'catalog');
  const reviewFile = join(root, 'review.json');
  await mkdir(join(source, 'programs'), { recursive: true });
  await writeFile(join(source, 'exercises.yaml'), `exercises:
  - key: machine_chest_press
    name: Machine Chest Press
    instructions: Use the machine's full controlled range of motion.
    stopping_guidance: Stop when another full repetition cannot be completed with controlled technique.
    warmup_guidance: Prepare with lighter sets as needed before the working set.
    rest_seconds: 180
    default_reps: { minimum: 6, maximum: 10 }
`);
  await writeFile(join(source, 'programs', 'machine-full-body.yaml'), `key: machine-full-body
name: Machine Full Body
recommended_weeks: 8
format: A / B / C
emphasis: Maximum stability, simple progression, and a low-skill environment for high effort.
workouts:
  - key: machine-full-body-a
    name: Workout A
    position: 1
    exercises:
      - key: machine-full-body-a-chest-press
        exercise: machine_chest_press
        position: 1
        reps: { minimum: 6, maximum: 10 }
`);

  let requestBody: unknown;
  const server = createServer(async (request, response) => {
    assert.equal(request.url, '/v1/maintenance/catalog/preview');
    assert.equal(request.headers.authorization, 'Bearer separate-publisher-secret');
    const chunks: Buffer[] = [];
    for await (const chunk of request) chunks.push(Buffer.from(chunk));
    requestBody = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({
      preview_id: 'preview-123',
      backend_fingerprint: 'empty',
      changes: [{ kind: 'add', program_key: 'machine-full-body', name: 'Machine Full Body' }],
      affected_programs: ['Machine Full Body'],
    }));
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  assert.ok(address && typeof address === 'object');

  try {
    const { stdout: output } = await execute(process.execPath, [
      '--import', 'tsx', 'scripts/catalog.ts', 'preview',
      '--environment', 'test', '--source', source, '--preview-file', reviewFile,
    ], {
      cwd: process.cwd(),
      env: {
        ...process.env,
        ONESET_CATALOG_API_TEST: `http://127.0.0.1:${address.port}`,
        ONESET_CATALOG_PUBLISH_TOKEN_TEST: 'separate-publisher-secret',
      },
    });

    assert.match(output, /Preview for test/);
    assert.match(output, /Machine Full Body/);
    assert.match(output, /preview-123/);
    assert.ok(requestBody && typeof requestBody === 'object');
    assert.equal((requestBody as { source?: { programs?: Array<{ key: string }> } }).source?.programs?.[0]?.key,
      'machine-full-body');
    const review = JSON.parse(await readFile(reviewFile, 'utf8')) as { backend_fingerprint?: string };
    assert.equal(review.backend_fingerprint, 'empty');
  } finally {
    server.close();
    await once(server, 'close');
    await rm(root, { recursive: true, force: true });
  }
});
