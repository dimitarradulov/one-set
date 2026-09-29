-- Replace the unused original schema with docs/database/oneset.dbml.
-- Fail if any original table gains rows before this migration is applied.
BEGIN;

LOCK TABLE
  public.workout_sessions_sets, public.workout_sessions,
  public.user_workout_exercises, public.user_programs, public.users,
  public.workout_exercises, public.program_workouts, public.exercises,
  public.workouts, public.workout_programs
IN ACCESS EXCLUSIVE MODE;

CREATE TEMP TABLE oneset_migration_empty_guard (
  all_tables_empty boolean NOT NULL CHECK (all_tables_empty)
);
INSERT INTO oneset_migration_empty_guard
SELECT
  NOT EXISTS (SELECT 1 FROM public.workout_sessions_sets) AND
  NOT EXISTS (SELECT 1 FROM public.workout_sessions) AND
  NOT EXISTS (SELECT 1 FROM public.user_workout_exercises) AND
  NOT EXISTS (SELECT 1 FROM public.user_programs) AND
  NOT EXISTS (SELECT 1 FROM public.users) AND
  NOT EXISTS (SELECT 1 FROM public.workout_exercises) AND
  NOT EXISTS (SELECT 1 FROM public.program_workouts) AND
  NOT EXISTS (SELECT 1 FROM public.exercises) AND
  NOT EXISTS (SELECT 1 FROM public.workouts) AND
  NOT EXISTS (SELECT 1 FROM public.workout_programs);
DROP TABLE oneset_migration_empty_guard;

DROP TABLE public.workout_sessions_sets;
DROP TABLE public.workout_sessions;
DROP TABLE public.user_workout_exercises;
DROP TABLE public.user_programs;
DROP TABLE public.users;
DROP TABLE public.workout_exercises;
DROP TABLE public.program_workouts;
DROP TABLE public.exercises;
DROP TABLE public.workouts;
DROP TABLE public.workout_programs;

CREATE TYPE public.weight_unit AS ENUM ('kg', 'lb');

CREATE TABLE public.workout_programs (
  id serial PRIMARY KEY,
  name text NOT NULL,
  recommended_weeks integer NOT NULL DEFAULT 8 CHECK (recommended_weeks > 0)
);

CREATE TABLE public.workouts (
  id serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE public.program_workouts (
  program_id integer NOT NULL REFERENCES public.workout_programs(id),
  workout_id integer NOT NULL REFERENCES public.workouts(id),
  position integer CHECK (position > 0),
  PRIMARY KEY (program_id, workout_id),
  UNIQUE (program_id, position)
);

CREATE TABLE public.exercises (
  id serial PRIMARY KEY,
  name text NOT NULL,
  instructions text NOT NULL,
  video_key text,
  reps_min integer NOT NULL,
  reps_max integer NOT NULL,
  rest_seconds integer NOT NULL CHECK (rest_seconds > 0),
  warmup_guidance jsonb NOT NULL CHECK (jsonb_typeof(warmup_guidance) = 'object'),
  CHECK (reps_min > 0 AND reps_max >= reps_min)
);

CREATE TABLE public.workout_exercises (
  id serial PRIMARY KEY,
  workout_id integer NOT NULL REFERENCES public.workouts(id),
  exercise_id integer NOT NULL REFERENCES public.exercises(id),
  position integer CHECK (position > 0),
  reps_min integer NOT NULL,
  reps_max integer NOT NULL,
  CHECK (reps_min > 0 AND reps_max >= reps_min),
  UNIQUE (workout_id, position)
);

CREATE TABLE public.users (
  id serial PRIMARY KEY,
  clerk_user_id text NOT NULL UNIQUE,
  preferred_unit public.weight_unit NOT NULL,
  training_days integer NOT NULL CHECK (training_days BETWEEN 2 AND 5),
  active_user_program_id uuid
);

CREATE TABLE public.user_programs (
  id uuid PRIMARY KEY,
  user_id integer NOT NULL REFERENCES public.users(id),
  workout_program_id integer NOT NULL REFERENCES public.workout_programs(id),
  started_at timestamptz NOT NULL
);
CREATE INDEX user_programs_resume_idx
  ON public.user_programs (user_id, workout_program_id, started_at, id);
ALTER TABLE public.users ADD CONSTRAINT users_active_user_program_id_fkey
  FOREIGN KEY (active_user_program_id) REFERENCES public.user_programs(id);

CREATE TABLE public.user_workout_exercises (
  user_program_id uuid NOT NULL REFERENCES public.user_programs(id),
  workout_exercise_id integer NOT NULL REFERENCES public.workout_exercises(id),
  exercise_id integer REFERENCES public.exercises(id),
  note text,
  rest_seconds integer CHECK (rest_seconds > 0),
  PRIMARY KEY (user_program_id, workout_exercise_id)
);

CREATE TABLE public.workout_sessions (
  id uuid PRIMARY KEY,
  user_program_id uuid NOT NULL REFERENCES public.user_programs(id),
  workout_id integer NOT NULL REFERENCES public.workouts(id),
  week_number integer NOT NULL CHECK (week_number > 0),
  workout_name text NOT NULL,
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  note text,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  CHECK (completed_at IS NULL OR completed_at >= started_at)
);
CREATE INDEX workout_sessions_history_idx
  ON public.workout_sessions (user_program_id, started_at, id);

CREATE TABLE public.workout_session_sets (
  workout_session_id uuid NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position > 0),
  workout_exercise_id integer NOT NULL REFERENCES public.workout_exercises(id),
  exercise_id integer NOT NULL REFERENCES public.exercises(id),
  prescription jsonb NOT NULL CHECK (jsonb_typeof(prescription) = 'object'),
  note text,
  weight numeric(10,3) CHECK (weight >= 0 AND weight <> 'NaN'::numeric),
  unit public.weight_unit NOT NULL,
  reps integer CHECK (reps > 0),
  completed_at timestamptz,
  PRIMARY KEY (workout_session_id, workout_exercise_id),
  UNIQUE (workout_session_id, position),
  CHECK (completed_at IS NULL OR (weight IS NOT NULL AND reps IS NOT NULL))
);
CREATE INDEX workout_session_sets_exercise_id_idx
  ON public.workout_session_sets (exercise_id);

CREATE TABLE public.completed_workouts (
  user_program_id uuid NOT NULL REFERENCES public.user_programs(id),
  week_number integer NOT NULL CHECK (week_number > 0),
  workout_id integer NOT NULL REFERENCES public.workouts(id),
  PRIMARY KEY (user_program_id, week_number, workout_id)
);

COMMIT;
