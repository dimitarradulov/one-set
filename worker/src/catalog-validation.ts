export type JsonObject = Record<string, unknown>;
export interface RepRange { minimum: number; maximum: number }
export interface CatalogExercise extends JsonObject {
  key: string;
  name: string;
  instructions: string;
  stopping_guidance: string;
  warmup_guidance: string;
  rest_seconds: number;
  default_reps: RepRange;
}
export interface CatalogSlot extends JsonObject {
  key: string;
  exercise: string;
  position: number;
  reps: RepRange;
  scope?: 'reps' | 'each_leg' | 'each_side';
  removed?: boolean;
}
export interface CatalogWorkout extends JsonObject {
  key: string;
  name: string;
  position: number;
  exercises: CatalogSlot[];
  removed?: boolean;
}
export interface CatalogProgram extends JsonObject {
  key: string;
  name: string;
  recommended_weeks: number;
  training_days_per_week: number;
  format: string;
  emphasis: string;
  workouts: CatalogWorkout[];
  removed?: boolean;
}
export interface CatalogSource extends JsonObject {
  exercises: CatalogExercise[];
  programs: CatalogProgram[];
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isNonEmpty(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isPositiveInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value > 0;
}

function isKey(value: unknown): value is string {
  return isNonEmpty(value) && /^[a-z0-9][a-z0-9_-]*$/.test(value);
}

function asObjects(value: unknown): JsonObject[] | undefined {
  return Array.isArray(value) && value.every(isObject) ? value : undefined;
}

function canonicalJSON(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJSON).join(',')}]`;
  if (isObject(value)) {
    const fields = Object.entries(value).sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0);
    return `{${fields.map(([key, field]) => `${JSON.stringify(key)}:${canonicalJSON(field)}`).join(',')}}`;
  }
  return JSON.stringify(value) ?? 'null';
}

function range(value: unknown): value is RepRange {
  return isObject(value) && isPositiveInteger(value.minimum) && isPositiveInteger(value.maximum)
    && value.maximum >= value.minimum && value.maximum <= 100;
}

function addUniqueKeyErrors(values: JsonObject[], label: string, errors: string[]): void {
  const seen = new Set<string>();
  for (const value of values) {
    if (!isKey(value.key)) errors.push(`${label} entry needs a stable lowercase key`);
    else if (seen.has(value.key)) errors.push(`${label} has duplicate key ${value.key}`);
    else seen.add(value.key);
  }
}

function checkOrdered(values: JsonObject[], label: string, errors: string[]): void {
  const positions: number[] = [];
  for (const value of values) {
    if (value.removed === true) continue;
    if (!isPositiveInteger(value.position)) errors.push(`${label} needs a positive position`);
    else positions.push(value.position);
  }
  positions.sort((first, second) => first - second);
  positions.forEach((position, index) => {
    if (position !== index + 1) errors.push(`${label} positions must be consecutive starting at 1`);
  });
}

function previousEntries(source: CatalogSource | undefined): {
  programs: Map<string, CatalogProgram>;
  workouts: Map<string, { program: CatalogProgram; workout: CatalogWorkout }>;
  slots: Map<string, { workout: CatalogWorkout; slot: CatalogSlot }>;
  exercises: Map<string, CatalogExercise>;
} {
  const programs = new Map<string, CatalogProgram>();
  const workouts = new Map<string, { program: CatalogProgram; workout: CatalogWorkout }>();
  const slots = new Map<string, { workout: CatalogWorkout; slot: CatalogSlot }>();
  const exercises = new Map<string, CatalogExercise>();
  for (const exercise of source?.exercises ?? []) exercises.set(exercise.key, exercise);
  for (const program of source?.programs ?? []) {
    programs.set(program.key, program);
    for (const workout of program.workouts) {
      workouts.set(workout.key, { program, workout });
      for (const slot of workout.exercises) slots.set(slot.key, { workout, slot });
    }
  }
  return { programs, workouts, slots, exercises };
}

export function validateCatalogSource(
  value: unknown,
  previous?: CatalogSource,
): { catalog?: CatalogSource; errors: string[] } {
  const errors: string[] = [];
  if (!isObject(value)) return { errors: ['catalog must be an object'] };
  const rawExercises = asObjects(value.exercises);
  const rawPrograms = asObjects(value.programs);
  if (!rawExercises) errors.push('exercises must be a list of objects');
  if (!rawPrograms || rawPrograms.length === 0) errors.push('programs must be a non-empty list of objects');
  if (!rawExercises || !rawPrograms) return { errors };

  addUniqueKeyErrors(rawExercises, 'exercise', errors);
  addUniqueKeyErrors(rawPrograms, 'program', errors);
  const exerciseKeys = new Set(rawExercises.filter(item => isKey(item.key)).map(item => String(item.key)));

  for (const exercise of rawExercises) {
    const label = `exercise ${String(exercise.key ?? '<missing>')}`;
    if (!isKey(exercise.key)) errors.push(`${label} needs a stable lowercase key`);
    for (const field of ['name', 'instructions', 'stopping_guidance', 'warmup_guidance']) {
      if (!isNonEmpty(exercise[field])) errors.push(`${label} needs ${field}`);
    }
    if (!isPositiveInteger(exercise.rest_seconds)) errors.push(`${label} needs positive rest_seconds`);
    if (!range(exercise.default_reps)) errors.push(`${label} needs positive default_reps bounds (maximum 100)`);
    if (exercise.video_key !== undefined && exercise.video_key !== null && !isNonEmpty(exercise.video_key)) {
      errors.push(`${label} video_key must be a non-empty string when supplied`);
    }
  }

  const programs: CatalogProgram[] = [];
  const workoutRows: JsonObject[] = [];
  const slotRows: JsonObject[] = [];
  for (const program of rawPrograms) {
    const label = `program ${String(program.key ?? '<missing>')}`;
    if (!isKey(program.key)) errors.push(`${label} needs a stable lowercase key`);
    for (const field of ['name', 'format', 'emphasis']) {
      if (!isNonEmpty(program[field])) errors.push(`${label} needs ${field}`);
    }
    if (!isPositiveInteger(program.recommended_weeks)) errors.push(`${label} needs positive recommended_weeks`);
    if (!isPositiveInteger(program.training_days_per_week) || program.training_days_per_week < 2
        || program.training_days_per_week > 5) errors.push(`${label} training_days_per_week must be 2–5`);
    if (program.removed !== undefined && typeof program.removed !== 'boolean') {
      errors.push(`${label} removed must be true or false`);
    }
    const rawWorkouts = asObjects(program.workouts);
    if (!rawWorkouts || rawWorkouts.length === 0) {
      errors.push(`${label} needs a non-empty workouts list`);
      continue;
    }
    addUniqueKeyErrors(rawWorkouts, `${label} workout`, errors);
    checkOrdered(rawWorkouts, `${label} workout`, errors);
    const workouts: CatalogWorkout[] = [];
    for (const workout of rawWorkouts) {
      const workoutLabel = `workout ${String(workout.key ?? '<missing>')}`;
      if (!isKey(workout.key)) errors.push(`${workoutLabel} needs a stable lowercase key`);
      if (!isNonEmpty(workout.name)) errors.push(`${workoutLabel} needs a name`);
      if (workout.removed !== undefined && typeof workout.removed !== 'boolean') {
        errors.push(`${workoutLabel} removed must be true or false`);
      }
      const rawSlots = asObjects(workout.exercises);
      if (!rawSlots || rawSlots.length === 0) {
        errors.push(`${workoutLabel} needs a non-empty exercises list`);
        continue;
      }
      addUniqueKeyErrors(rawSlots, `${workoutLabel} slot`, errors);
      checkOrdered(rawSlots, `${workoutLabel} slot`, errors);
      const slots: CatalogSlot[] = [];
      for (const slot of rawSlots) {
        const slotLabel = `slot ${String(slot.key ?? '<missing>')}`;
        if (!isKey(slot.key)) errors.push(`${slotLabel} needs a stable lowercase key`);
        if (!isKey(slot.exercise) || !exerciseKeys.has(String(slot.exercise))) {
          errors.push(`${slotLabel} references an unknown exercise`);
        }
        if (slot.removed !== undefined && typeof slot.removed !== 'boolean') {
          errors.push(`${slotLabel} removed must be true or false`);
        }
        if (slot.scope !== undefined && !['reps', 'each_leg', 'each_side'].includes(String(slot.scope))) {
          errors.push(`${slotLabel} scope must be reps, each_leg, or each_side`);
        }
        if (!range(slot.reps)) errors.push(`${slotLabel} needs positive rep bounds (maximum 100)`);
        slots.push(slot as unknown as CatalogSlot);
      }
      workouts.push({ ...workout, exercises: slots } as unknown as CatalogWorkout);
      workoutRows.push(workout);
      slotRows.push(...rawSlots);
    }
    programs.push({ ...program, workouts } as unknown as CatalogProgram);
  }
  addUniqueKeyErrors(workoutRows, 'workout', errors);
  addUniqueKeyErrors(slotRows, 'slot', errors);

  const catalog = {
    ...value,
    exercises: rawExercises as unknown as CatalogExercise[],
    programs,
  } as CatalogSource;

  if (previous) {
    const before = previousEntries(previous);
    const after = previousEntries(catalog);
    for (const [key] of before.programs) {
      if (!after.programs.has(key)) errors.push(`previously published program ${key} is missing; mark it removed explicitly`);
    }
    for (const [key, entry] of before.workouts) {
      const replacement = after.workouts.get(key);
      if (!replacement) errors.push(`previously published workout ${key} is missing; mark it removed explicitly`);
      else if (replacement.program.key !== entry.program.key) {
        errors.push(`workout key ${key} cannot move to a different program`);
      }
    }
    for (const [key, entry] of before.slots) {
      const replacement = after.slots.get(key);
      if (!replacement) errors.push(`previously published slot ${key} is missing; mark it removed explicitly`);
      else if (replacement.slot.exercise !== entry.slot.exercise) {
        errors.push(`slot key ${key} cannot be reused for a different exercise`);
      } else if (replacement.workout.key !== entry.workout.key) {
        errors.push(`slot key ${key} cannot move to a different workout`);
      }
    }
    for (const [key] of before.exercises) {
      if (!after.exercises.has(key)) errors.push(`previously published exercise ${key} is missing`);
    }
  }

  return { catalog, errors };
}

export function diffCatalog(previous: CatalogSource | undefined, next: CatalogSource): {
  changes: Array<{ kind: string; program_key?: string; name?: string }>;
  affectedPrograms: string[];
} {
  const before = previousEntries(previous);
  const after = previousEntries(next);
  const changes: Array<{ kind: string; program_key?: string; name?: string }> = [];
  const affected = new Set<string>();

  for (const program of next.programs) {
    const oldProgram = before.programs.get(program.key);
    if (!oldProgram) {
      changes.push({ kind: 'add', program_key: program.key, name: program.name });
      affected.add(program.name);
    } else if (canonicalJSON(oldProgram) !== canonicalJSON(program)) {
      changes.push({ kind: program.removed ? 'remove' : 'update', program_key: program.key, name: program.name });
      affected.add(program.name);
    }
  }

  for (const exercise of next.exercises) {
    const oldExercise = before.exercises.get(exercise.key);
    if (oldExercise && canonicalJSON(oldExercise) !== canonicalJSON(exercise)) {
      changes.push({ kind: 'update exercise', name: exercise.name });
      for (const program of [...(previous?.programs ?? []), ...next.programs]) {
        if (program.workouts.some(workout => workout.exercises.some(slot => slot.exercise === exercise.key))) {
          affected.add(program.name);
        }
      }
    }
  }

  for (const [key, oldProgram] of before.programs) {
    if (!after.programs.has(key)) affected.add(oldProgram.name);
  }
  return { changes, affectedPrograms: [...affected].sort() };
}
