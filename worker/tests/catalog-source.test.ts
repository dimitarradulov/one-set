import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { parse } from 'yaml';
import { validateCatalogSource } from '../src/catalog-validation.js';
import { generateBundledSwift } from '../src/catalog-generation.js';

const execute = promisify(execFile);

test('the ten authored programs generate the bundled catalog without losing prescriptions', async () => {
  const output = await mkdtemp(join(tmpdir(), 'oneset-catalog-source-'));
  const generatedSwift = join(output, 'BundledProgramCatalog.swift');
  try {
    await execute(process.execPath, [
      '--import', 'tsx', 'scripts/catalog.ts', 'generate-bundled',
      '--source', 'catalog', '--output', generatedSwift,
    ], { cwd: process.cwd() });

    const expectedCounts: Record<string, number> = {
      'full-body': 21,
      'upper-lower': 22,
      'push-pull-legs': 19,
      'bro-split': 25,
      'minimalist-full-body': 12,
      'v-taper': 19,
      powerhouse: 20,
      'classic-physique': 19,
      'free-weight-full-body': 18,
      'machine-full-body': 22,
    };
    const programFiles = (await readdir('catalog/programs')).filter(file => file.endsWith('.yaml')).sort();
    assert.equal(programFiles.length, 10);
    const programs = await Promise.all(programFiles.map(async file => parse(
      await readFile(join('catalog/programs', file), 'utf8'),
    ) as { key: string; recommended_weeks: number; workouts: Array<{ banner?: string; exercises: Array<{ removed?: boolean }> }> }));
    assert.deepEqual(programs.map(program => program.key), Object.keys(expectedCounts));
    for (const program of programs) {
      assert.equal(program.recommended_weeks, 8);
      assert.equal(program.workouts.flatMap(workout => workout.exercises).filter(slot => !slot.removed).length, expectedCounts[program.key]);
    }
    const workouts = programs.flatMap(program => program.workouts);
    assert.equal(workouts.length, 32);
    assert.ok(workouts.every(workout => typeof workout.banner === 'string'));
    assert.deepEqual([...new Set(workouts.map(workout => workout.banner))].sort(), [
      'arms', 'back-pull', 'chest-push', 'general-gym', 'lower-body', 'shoulders', 'upper-body',
    ]);
    const exerciseDocument = parse(await readFile('catalog/exercises.yaml', 'utf8')) as {
      exercises: Array<Record<string, unknown>>;
    };
    assert.equal(exerciseDocument.exercises.length, 47);
    for (const exercise of exerciseDocument.exercises) {
      assert.equal(typeof exercise.instructions, 'string');
      assert.equal(typeof exercise.stopping_guidance, 'string');
      assert.equal(typeof exercise.warmup_guidance, 'string');
      assert.equal(typeof exercise.rest_seconds, 'number');
      assert.ok(exercise.default_reps);
      assert.equal(exercise.video_key, undefined);
    }
    const source = await readFile('catalog/programs/10-machine-full-body.yaml', 'utf8');
    const generated = await readFile(generatedSwift, 'utf8');
    const checkedIn = await readFile('../OneSet/Services/Catalog/BundledProgramCatalog.swift', 'utf8');
    assert.match(source, /recommended_weeks: 8/);
    assert.match(generated, /id: "full-body"/);
    assert.match(generated, /id: "machine-full-body"/);
    assert.match(generated, /stoppingGuidance:/);
    assert.ok(generated.includes('banner: "lower-body"'));
    assert.equal(generated, checkedIn);
  } finally {
    await rm(output, { recursive: true, force: true });
  }
});

test('catalog validation preserves a valid banner identifier unknown to this app release', async () => {
  const programFiles = (await readdir('catalog/programs')).filter(file => file.endsWith('.yaml')).sort();
  const programs = await Promise.all(programFiles.map(async file => parse(
    await readFile(join('catalog/programs', file), 'utf8'),
  ) as Record<string, unknown>));
  const workout = (programs[0]!.workouts as Array<Record<string, unknown>>)[0]!;
  workout.banner = 'future-theme-v2';
  const exercises = parse(await readFile('catalog/exercises.yaml', 'utf8')) as Record<string, unknown>;
  const result = validateCatalogSource({ exercises: exercises.exercises, programs });
  assert.deepEqual(result.errors, []);
  assert.equal(result.catalog?.programs[0]?.workouts[0]?.banner, 'future-theme-v2');
});

test('program metadata, workout order, slot order, rep ranges, and unilateral scope match the library', async () => {
  const identities = [
    'full-body', 'upper-lower', 'push-pull-legs', 'bro-split', 'minimalist-full-body',
    'v-taper', 'powerhouse', 'classic-physique', 'free-weight-full-body', 'machine-full-body',
  ];
  const programs = new Map<string, {
    key: string;
    name: string;
    format: string;
    emphasis: string;
    workouts: Array<{ name: string; exercises: Array<{
      exercise: string; reps: { minimum: number; maximum: number }; scope?: string; removed?: boolean;
    }> }>;
  }>();
  const exerciseDocument = parse(await readFile('catalog/exercises.yaml', 'utf8')) as {
    exercises: Array<{ key: string; name: string; stopping_guidance: string }>;
  };
  const exerciseNames = new Map(exerciseDocument.exercises.map(exercise => [exercise.key, exercise.name]));
  for (const file of (await readdir('catalog/programs')).filter(path => path.endsWith('.yaml'))) {
    const program = parse(await readFile(join('catalog/programs', file), 'utf8')) as {
      key: string; name: string; format: string; emphasis: string;
      workouts: Array<{ name: string; exercises: Array<{
        exercise: string; reps: { minimum: number; maximum: number }; scope?: string; removed?: boolean;
      }> }>;
    };
    programs.set(program.key, program);
  }

  const source = await readFile('../docs/HIT_Workout_Program_Library.md', 'utf8');
  const titleToKey = new Map([
    ['Full Body', 'full-body'], ['Upper / Lower', 'upper-lower'], ['Push / Pull / Legs', 'push-pull-legs'],
    ['Bro Split', 'bro-split'], ['Minimalist Full Body', 'minimalist-full-body'], ['V-Taper', 'v-taper'],
    ['Powerhouse', 'powerhouse'], ['Classic Physique', 'classic-physique'],
    ['Free-Weight Full Body', 'free-weight-full-body'], ['Machine Full Body', 'machine-full-body'],
  ]);
  const sections = [...source.matchAll(/^# (\d+)\. (.+)$/gm)];
  assert.equal(sections.length, 10);
  for (let index = 0; index < sections.length; index++) {
    const section = sections[index]!;
    const key = titleToKey.get(section[2]!);
    assert.ok(key);
    const start = section.index!;
    const sectionContentStart = start + section[0]!.length;
    const nextHeadingOffset = source.slice(sectionContentStart).search(/^# /m);
    const end = nextHeadingOffset < 0 ? source.length : sectionContentStart + nextHeadingOffset;
    const text = source.slice(start, end);
    const program = programs.get(key);
    assert.ok(program);
    assert.equal(program.name, section[2]);
    assert.equal(program.workouts.length, Number(text.match(/\*\*Frequency:\*\* (\d+) days per week/)?.[1]));
    const sourceEmphasis = text.match(/\*\*(?:Best for|Visual goal):\*\* ([^\n<]+)/)?.[1];
    assert.equal(program.emphasis, sourceEmphasis);
    const sourceFormat = text.match(/\*\*Format:\*\* ([^\n<]+)/)?.[1];
    if (sourceFormat) assert.equal(program.format, sourceFormat);

    const sourceWorkouts = new Map<string, Array<{
      name: string; minimum: number; maximum: number; scope: string; failure: string;
    }>>();
    let workoutName: string | undefined;
    for (const line of text.split('\n')) {
      const heading = line.match(/^## (.+)$/);
      if (heading) {
        // These published programs use the library's day prefix for ordering only.
        workoutName = key === 'powerhouse' || key === 'classic-physique'
          ? heading[1]!.replace(/^Day \d+ - /, '')
          : heading[1]!;
        sourceWorkouts.set(workoutName, []);
        continue;
      }
      const row = line.match(/^\|\s*\d+\s*\|\s*(.+?)\s*\|\s*(\d+)[–-](\d+)(?: (each leg|each side))?\s*\|\s*(TF|MMF)\s*\|$/);
      if (row && workoutName) {
        sourceWorkouts.get(workoutName)!.push({
          name: row[1]!, minimum: Number(row[2]), maximum: Number(row[3]), scope: row[4] ?? 'reps', failure: row[5]!,
        });
      }
    }
    // Published Powerhouse updates from the November 11 and 13 catalog publications.
    if (key === 'powerhouse') {
      const [torso, thighs, shoulders] = sourceWorkouts.values();
      torso!.splice(6, 1, { name: 'Dumbbell Shrug', minimum: 8, maximum: 12, scope: 'reps', failure: 'TF' });
      thighs!.splice(4, 1, { name: 'Dumbbell Wrist Curl', minimum: 12, maximum: 20, scope: 'reps', failure: 'TF' });
      thighs!.splice(2, 1);
      sourceWorkouts.clear();
      sourceWorkouts.set('Torso Density + Arms', torso!);
      sourceWorkouts.set('Thighs + Posterior Chain + Forearms', thighs!);
      sourceWorkouts.set('Upper Back + Shoulder Girdle + Traps', shoulders!);
      assert.equal(program.workouts.flatMap(workout => workout.exercises).filter(slot => slot.removed).length, 5);
    }
    assert.deepEqual(program.workouts.map(workout => workout.name), [...sourceWorkouts.keys()]);
    for (const workout of program.workouts) {
      const sourceSlots = sourceWorkouts.get(workout.name)!;
      const activeSlots = workout.exercises.filter(slot => !slot.removed);
      assert.equal(activeSlots.length, sourceSlots.length);
      activeSlots.forEach((slot, slotIndex) => {
        const authored = sourceSlots[slotIndex]!;
        assert.equal(exerciseNames.get(slot.exercise), authored.name);
        assert.equal(slot.reps.minimum, authored.minimum);
        assert.equal(slot.reps.maximum, authored.maximum);
        assert.equal(slot.scope ?? 'reps', authored.scope === 'each leg' ? 'each_leg' : authored.scope === 'each side' ? 'each_side' : 'reps');
        const stopping = exerciseDocument.exercises.find(exercise => exercise.key === slot.exercise)?.stopping_guidance ?? '';
        assert.equal(stopping, authored.failure === 'TF'
          ? 'Stop when you cannot complete another rep without losing position or changing your form.'
          : 'Continue until you cannot complete another full rep through the planned range with controlled form.');
      });
    }
  }
});

test('catalog supersets require two adjacent active slots in workout order', async () => {
  const exercises = parse(await readFile('catalog/exercises.yaml', 'utf8')).exercises;
  const program = parse(await readFile('catalog/programs/01-full-body.yaml', 'utf8'));
  const source = { exercises, programs: [program] };
  const [workout, otherWorkout] = program.workouts;
  const [first, second, third] = workout.exercises;
  const pair = (a: string, b: string) => ({ first_slot_id: a, second_slot_id: b });

  assert.deepEqual(validateCatalogSource(source).errors, []);
  workout.supersets = [pair(first.key, second.key)];
  const validation = validateCatalogSource(source);
  assert.deepEqual(validation.errors, []);
  assert.match(generateBundledSwift(validation.catalog!), /SupersetPair\(firstSlotID:/);

  for (const invalid of [
    [pair(first.key, first.key)],
    [pair(second.key, first.key)],
    [pair(first.key, third.key)],
    [pair(first.key, otherWorkout.exercises[0].key)],
    [pair(first.key, second.key), pair(second.key, third.key)],
  ]) {
    workout.supersets = invalid;
    assert.ok(validateCatalogSource(source).errors.some(error => error.includes('superset')));
  }
  workout.supersets = [pair(first.key, second.key)];
  second.removed = true;
  assert.ok(validateCatalogSource(source).errors.some(error => error.includes('superset')));
});
