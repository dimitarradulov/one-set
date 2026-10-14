#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parse } from 'yaml';
import { validateCatalogSource, type CatalogSource, type JsonObject } from '../src/catalog-validation.js';

interface PreviewResult {
  preview_id: string;
  backend_fingerprint: string;
  changes: Array<{ kind: string; program_key?: string; name?: string }>;
  affected_programs: string[];
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseYaml(text: string, file: string): unknown {
  try {
    return parse(text, { uniqueKeys: true });
  } catch (error) {
    throw new Error(`${file}: ${error instanceof Error ? error.message : 'invalid YAML'}`);
  }
}

async function readCatalog(directory: string): Promise<JsonObject> {
  const exercisePath = join(directory, 'exercises.yaml');
  const exerciseDocument = parseYaml(await readFile(exercisePath, 'utf8'), exercisePath);
  if (!isObject(exerciseDocument)) throw new Error(`${exercisePath}: expected an object`);
  const programDirectory = join(directory, 'programs');
  const files = (await readdir(programDirectory)).filter(file => file.endsWith('.yaml')).sort();
  if (files.length === 0) throw new Error(`${programDirectory}: no .yaml program files found`);
  const programs: JsonObject[] = [];
  for (const file of files) {
    const path = join(programDirectory, file);
    const document = parseYaml(await readFile(path, 'utf8'), path);
    if (!isObject(document)) throw new Error(`${path}: expected a program object`);
    programs.push(document);
  }
  return { exercises: exerciseDocument.exercises, programs };
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function parseArguments(args: string[]): { command: string; options: Map<string, string> } {
  const [command, ...tail] = args;
  const options = new Map<string, string>();
  for (let index = 0; index < tail.length; index++) {
    const key = tail[index];
    if (key === '--check') {
      options.set('check', 'true');
      continue;
    }
    if (!key.startsWith('--') || index + 1 >= tail.length) throw new Error(`Unexpected argument ${key}`);
    options.set(key.slice(2), tail[++index]);
  }
  return { command: command ?? '', options };
}

function envBinding(prefix: string, environment: string): string | undefined {
  return process.env[`${prefix}_${environment.toUpperCase().replaceAll('-', '_')}`];
}

function usage(): string {
  return [
    'Usage:',
    '  npm run catalog -- generate-bundled [--source <directory>] [--output <path>] [--check]',
    '  npm run catalog -- preview --environment <name> [--source <directory>] [--preview-file <path>]',
    '  npm run catalog -- publish --environment <name> [--source <directory>] [--preview-file <path>]',
  ].join('\n');
}

function swiftString(value: string): string {
  return JSON.stringify(value);
}

function swiftRepRange(range: { minimum: number; maximum: number }, scope?: string): string {
  const scopeName = scope === 'each_leg' ? '.eachLeg' : scope === 'each_side' ? '.eachSide' : '.reps';
  return `RepTarget(minimum: ${range.minimum}, maximum: ${range.maximum}, scope: ${scopeName})`;
}

function generateBundledSwift(catalog: CatalogSource): string {
  const exercises = new Map(catalog.exercises.map(exercise => [exercise.key, exercise]));
  const programs = catalog.programs.map(program => {
    const workouts = program.workouts.filter(workout => workout.removed !== true).map(workout => {
      const slots = workout.exercises.filter(slot => slot.removed !== true).map(slot => {
        const exercise = exercises.get(slot.exercise);
        if (!exercise) throw new Error(`slot ${slot.key} references missing exercise ${slot.exercise}`);
        const videoKey = typeof exercise.video_key === 'string' ? swiftString(exercise.video_key) : 'nil';
        const target = swiftRepRange(slot.reps, slot.scope);
        const defaults = swiftRepRange(exercise.default_reps);
        return [
          '            WorkoutExercise(',
          `              id: ${swiftString(slot.key)}, exerciseKey: ${swiftString(exercise.key)},`,
          `              name: ${swiftString(exercise.name)}, repTarget: ${target},`,
          `              instructions: ${swiftString(exercise.instructions)},`,
          `              stoppingGuidance: ${swiftString(exercise.stopping_guidance)},`,
          `              warmupGuidance: ${swiftString(exercise.warmup_guidance)},`,
          `              restSeconds: ${exercise.rest_seconds}, defaultRepTarget: ${defaults},`,
          `              videoKey: ${videoKey}`, '            )',
        ].join('\n');
      });
      return [
        '        WorkoutTemplate(',
        `          id: ${swiftString(workout.key)}, name: ${swiftString(workout.name)},`,
        '          exercises: [', slots.map(slot => slot.split('\n').map(line => `  ${line}`).join('\n')).join(',\n'),
        '          ]', '        )',
      ].join('\n');
    });
    return [
      '    TrainingProgram(',
      `      id: ${swiftString(program.key)}, name: ${swiftString(program.name)},`,
      `      format: ${swiftString(program.format)},`,
      `      emphasis: ${swiftString(program.emphasis)},`,
      '      workouts: [', workouts.map(workout => workout.split('\n').map(line => `  ${line}`).join('\n')).join(',\n'),
      `      ], recommendedWeeks: ${program.recommended_weeks}, isOffered: ${program.removed !== true}`,
      '    )',
    ].join('\n');
  });
  return [
    'import Foundation', '',
    'extension ProgramCatalog {',
    '  static var bundled: ProgramCatalog { ProgramCatalog(programs: [',
    programs.map(program => program.split('\n').map(line => `  ${line}`).join('\n')).join(',\n'),
    '  ]) }', '}', '',
  ].join('\n');
}

async function generateBundledCommand(options: Map<string, string>): Promise<void> {
  const sourceDirectory = resolve(options.get('source') ?? 'catalog');
  const output = resolve(options.get('output') ?? '../OneSet/Services/Catalog/BundledProgramCatalog.swift');
  const rawCatalog = await readCatalog(sourceDirectory);
  const { catalog, errors } = validateCatalogSource(rawCatalog);
  if (errors.length > 0 || !catalog) throw new Error(`Catalog validation failed:\n- ${errors.join('\n- ')}`);
  const generated = generateBundledSwift(catalog);
  if (options.get('check') === 'true') {
    let current: string;
    try {
      current = await readFile(output, 'utf8');
    } catch {
      throw new Error(`Generated fallback is missing: ${output}`);
    }
    if (current !== generated) throw new Error(`Generated fallback is stale: ${output}; run generate-bundled.`);
    console.log(`Bundled fallback matches ${sourceDirectory}.`);
    return;
  }
  await writeFile(output, generated);
  console.log(`Generated bundled fallback: ${output}`);
}

async function main(args: string[]): Promise<void> {
  const { command, options } = parseArguments(args);
  if (command === 'generate-bundled') {
    await generateBundledCommand(options);
    return;
  }
  const environment = options.get('environment');
  if (!['preview', 'publish'].includes(command) || !environment || !/^[a-z][a-z0-9-]*$/.test(environment)) {
    throw new Error(usage());
  }
  const baseURL = envBinding('ONESET_CATALOG_API', environment);
  const token = envBinding('ONESET_CATALOG_PUBLISH_TOKEN', environment);
  if (!baseURL || !token) {
    throw new Error(`Set ONESET_CATALOG_API_${environment.toUpperCase().replaceAll('-', '_')} and its publisher token.`);
  }
  const sourceDirectory = resolve(options.get('source') ?? 'catalog');
  const previewFile = resolve(options.get('preview-file') ?? '.oneset-catalog-preview.json');
  const rawCatalog = await readCatalog(sourceDirectory);
  const { catalog, errors: validation } = validateCatalogSource(rawCatalog);
  if (validation.length > 0) throw new Error(`Catalog validation failed:\n- ${validation.join('\n- ')}`);
  if (!catalog) throw new Error('Catalog validation failed.');
  const sourceJSON = JSON.stringify(catalog);
  const sourceFingerprint = sha256(sourceJSON);
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

  if (command === 'preview') {
    const response = await fetch(new URL('/v1/maintenance/catalog/preview', baseURL), {
      method: 'POST', headers, body: JSON.stringify({ source: catalog, source_fingerprint: sourceFingerprint }),
    });
    const result = await response.json() as Partial<PreviewResult> & { error?: { code?: string } };
    if (!response.ok || !result.preview_id || !result.backend_fingerprint) {
      throw new Error(`Preview failed (${response.status}): ${result.error?.code ?? 'TEMPORARY_FAILURE'}`);
    }
    await writeFile(previewFile, JSON.stringify({
      environment, source_directory: sourceDirectory, source_fingerprint: sourceFingerprint,
      backend_fingerprint: result.backend_fingerprint, preview_id: result.preview_id,
    }, null, 2) + '\n');
    console.log(`Preview for ${environment}`);
    for (const change of result.changes ?? []) {
      console.log(`  ${change.kind}: ${change.name ?? change.program_key ?? 'catalog'}`);
    }
    console.log(`Affected programs: ${(result.affected_programs ?? []).join(', ') || 'none'}`);
    console.log(`Preview ID: ${result.preview_id}`);
    console.log(`Review file: ${previewFile}`);
    return;
  }

  let review: { environment?: string; source_fingerprint?: string; backend_fingerprint?: string; preview_id?: string };
  try {
    review = JSON.parse(await readFile(previewFile, 'utf8')) as typeof review;
  } catch {
    throw new Error(`Read a preview first: ${previewFile} is missing or invalid.`);
  }
  if (review.environment !== environment || review.source_fingerprint !== sourceFingerprint
      || !review.backend_fingerprint || !review.preview_id) {
    throw new Error('The source or environment changed since preview; run preview again.');
  }
  const response = await fetch(new URL('/v1/maintenance/catalog/publish', baseURL), {
    method: 'POST', headers,
    body: JSON.stringify({ source: catalog, source_fingerprint: sourceFingerprint,
      backend_fingerprint: review.backend_fingerprint, preview_id: review.preview_id }),
  });
  const result = await response.json() as { publication_id?: string; error?: { code?: string } };
  if (!response.ok || !result.publication_id) {
    throw new Error(`Publish failed (${response.status}): ${result.error?.code ?? 'TEMPORARY_FAILURE'}`);
  }
  console.log(`Published catalog to ${environment}: ${result.publication_id}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).catch(error => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
