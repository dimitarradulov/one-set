import { stringify } from 'yaml';
import type { CatalogSource } from './catalog-validation';

function swiftString(value: string): string {
  return JSON.stringify(value);
}

function swiftRepRange(range: { minimum: number; maximum: number }, scope?: string): string {
  const scopeName = scope === 'each_leg' ? '.eachLeg' : scope === 'each_side' ? '.eachSide' : '.reps';
  return `RepTarget(minimum: ${range.minimum}, maximum: ${range.maximum}, scope: ${scopeName})`;
}

/** The bundled Swift output used by the CLI and repository synchronization. */
export function generateBundledSwift(catalog: CatalogSource): string {
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
        ...(typeof workout.banner === 'string' ? [`          banner: ${swiftString(workout.banner)},`] : []),
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

/** Complete readable source files for one exact, validated publication. */
export function catalogSourceFiles(catalog: CatalogSource, publicationID: string, sourceFingerprint: string): Record<string, string> {
  const files: Record<string, string> = {
    'worker/catalog/exercises.yaml': stringify({ exercises: catalog.exercises }, { lineWidth: 110 }),
    'worker/catalog/.publication.json': `${JSON.stringify({ publication_id: publicationID, source_fingerprint: sourceFingerprint }, null, 2)}\n`,
  };
  catalog.programs.forEach((program, index) => {
    const sequence = String(index + 1).padStart(2, '0');
    files[`worker/catalog/programs/${sequence}-${program.key}.yaml`] = stringify(program, { lineWidth: 110 });
  });
  files['OneSet/Services/Catalog/BundledProgramCatalog.swift'] = generateBundledSwift(catalog);
  return files;
}
