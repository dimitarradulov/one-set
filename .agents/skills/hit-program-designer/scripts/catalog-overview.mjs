#!/usr/bin/env node
// Prints a compact view of the authored catalog for program design.
// Run from the repository root: node .agents/skills/hit-program-designer/scripts/catalog-overview.mjs [catalog-dir]
import { createRequire } from 'node:module';
import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = process.cwd();
const require = createRequire(join(root, 'worker', 'package.json'));
const { parse } = require('yaml');
const catalogDirectory = resolve(process.argv[2] ?? join(root, 'worker', 'catalog'));

const exercises = parse(readFileSync(join(catalogDirectory, 'exercises.yaml'), 'utf8')).exercises;
const byKey = new Map(exercises.map(exercise => [exercise.key, exercise]));
const programFiles = readdirSync(join(catalogDirectory, 'programs')).filter(file => file.endsWith('.yaml')).sort();
const banners = new Set();
const usage = new Map();

for (const file of programFiles) {
  const program = parse(readFileSync(join(catalogDirectory, 'programs', file), 'utf8'));
  const removed = program.removed ? ' [REMOVED]' : '';
  console.log(`\n## ${program.name} (${program.key}, ${file})${removed}`);
  console.log(`   format: ${program.format} | recommended_weeks: ${program.recommended_weeks}`);
  for (const workout of [...program.workouts].sort((a, b) => a.position - b.position)) {
    if (workout.banner) banners.add(workout.banner);
    const parity = workout.week_parity ? ` (${workout.week_parity} weeks)` : '';
    console.log(`   [${workout.position}] ${workout.name}${parity}${workout.removed ? ' [REMOVED]' : ''}`);
    const pairs = new Map((workout.supersets ?? []).map(pair => [pair.first_slot_id, pair.second_slot_id]));
    const active = workout.exercises.filter(slot => !slot.removed).sort((a, b) => a.position - b.position);
    for (const slot of active) {
      const exercise = byKey.get(slot.exercise);
      const scope = slot.scope && slot.scope !== 'reps' ? ` ${slot.scope}` : '';
      const pair = pairs.has(slot.key) ? '  -> superset with next' : '';
      console.log(`      ${slot.position}. ${exercise?.name ?? `UNKNOWN ${slot.exercise}`} ${slot.reps.minimum}-${slot.reps.maximum}${scope}${pair}`);
      if (!program.removed && !workout.removed) usage.set(slot.exercise, (usage.get(slot.exercise) ?? 0) + 1);
    }
  }
}

console.log('\n## Exercises (key | name | default reps | rest s | active uses)');
for (const exercise of [...exercises].sort((a, b) => a.name.localeCompare(b.name))) {
  const reps = `${exercise.default_reps.minimum}-${exercise.default_reps.maximum}`;
  console.log(`   ${exercise.key} | ${exercise.name} | ${reps} | ${exercise.rest_seconds} | ${usage.get(exercise.key) ?? 0}`);
}
console.log(`\nBanners in use: ${[...banners].sort().join(', ')}`);
const numbers = programFiles.map(file => Number.parseInt(file, 10)).filter(Number.isFinite);
console.log(`Next program file number: ${String(Math.max(0, ...numbers) + 1).padStart(2, '0')}`);
