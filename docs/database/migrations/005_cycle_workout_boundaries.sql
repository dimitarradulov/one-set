BEGIN;

-- Keep a cycle's current training week stable when its workout rotation changes.
ALTER TABLE public.user_programs
  ADD COLUMN current_training_week integer NOT NULL DEFAULT 1
  CHECK (current_training_week > 0);

UPDATE public.user_programs AS cycles
SET current_training_week = (
  SELECT coalesce(min(candidate.week_number), 1)::integer AS current_week
  FROM generate_series(
    1,
    coalesce((
      SELECT max(marks.week_number)
      FROM public.completed_workouts AS marks
      WHERE marks.user_program_id = cycles.id
    ), 0) + 1
  ) AS candidate(week_number)
  WHERE EXISTS (
    SELECT 1
    FROM public.program_workouts AS membership
    WHERE membership.program_id = cycles.workout_program_id
      AND membership.position IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.completed_workouts AS marks
        WHERE marks.user_program_id = cycles.id
          AND marks.week_number = candidate.week_number
          AND marks.workout_id = membership.workout_id
      )
  )
);

CREATE FUNCTION public.prevent_cycle_week_regression()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.current_training_week < OLD.current_training_week THEN
    RAISE EXCEPTION USING MESSAGE = 'CURRENT_TRAINING_WEEK_REGRESSION', ERRCODE = '22000';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER user_programs_current_week_is_monotonic
BEFORE UPDATE OF current_training_week ON public.user_programs
FOR EACH ROW EXECUTE FUNCTION public.prevent_cycle_week_regression();

CREATE TABLE public.user_program_workout_periods (
  user_program_id uuid NOT NULL REFERENCES public.user_programs(id) ON DELETE CASCADE,
  workout_id integer NOT NULL REFERENCES public.workouts(id),
  starts_week integer NOT NULL CHECK (starts_week > 0),
  ends_week integer CHECK (ends_week >= starts_week),
  PRIMARY KEY (user_program_id, workout_id, starts_week)
);

INSERT INTO public.user_program_workout_periods (
  user_program_id, workout_id, starts_week
)
SELECT cycles.id, membership.workout_id, 1
FROM public.user_programs AS cycles
JOIN public.program_workouts AS membership
  ON membership.program_id = cycles.workout_program_id
WHERE membership.position IS NOT NULL;

CREATE FUNCTION public.initialize_cycle_workout_periods()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Serialize cycle initialization with catalog publication so a concurrent
  -- cycle sees either the complete old or complete new workout membership set.
  PERFORM 1 FROM public.catalog_state
  WHERE singleton = true FOR UPDATE;

  INSERT INTO public.user_program_workout_periods (
    user_program_id, workout_id, starts_week
  )
  SELECT NEW.id, membership.workout_id, 1
  FROM public.program_workouts AS membership
  WHERE membership.program_id = NEW.workout_program_id
    AND membership.position IS NOT NULL;
  RETURN NEW;
END;
$$;

CREATE TRIGGER user_programs_initialize_workout_periods
AFTER INSERT ON public.user_programs
FOR EACH ROW EXECUTE FUNCTION public.initialize_cycle_workout_periods();

CREATE FUNCTION public.required_workouts_for_cycle_week(
  cycle_id uuid,
  target_week integer
) RETURNS TABLE (workout_id integer, workout_position integer)
LANGUAGE sql STABLE AS $$
  SELECT membership.workout_id, membership.position
  FROM public.user_programs AS cycles
  JOIN public.program_workouts AS membership
    ON membership.program_id = cycles.workout_program_id
  JOIN public.user_program_workout_periods AS periods
    ON periods.user_program_id = cycles.id
   AND periods.workout_id = membership.workout_id
  WHERE cycles.id = cycle_id
    AND target_week >= cycles.current_training_week
    AND target_week >= periods.starts_week
    AND (periods.ends_week IS NULL OR target_week <= periods.ends_week)
    AND membership.position IS NOT NULL
  ORDER BY membership.position;
$$;

-- Preserve the stable catalog writer, adding cycle-scoped progress boundaries
-- around its atomic membership update.
ALTER FUNCTION public.publish_catalog(text, text, text, jsonb)
  RENAME TO publish_catalog_catalog_only;

CREATE FUNCTION public.publish_catalog(
  expected_backend_fingerprint text,
  incoming_publication_id text,
  incoming_source_fingerprint text,
  incoming_source jsonb
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  publication_result text;
BEGIN
  PERFORM 1 FROM public.catalog_state
  WHERE singleton = true FOR UPDATE;

  DROP TABLE IF EXISTS pg_temp.catalog_membership_before_publish;
  DROP TABLE IF EXISTS pg_temp.catalog_cycles_before_publish;
  CREATE TEMP TABLE catalog_cycles_before_publish ON COMMIT DROP AS
  SELECT id AS user_program_id, workout_program_id AS program_id,
    current_training_week
  FROM public.user_programs;

  CREATE TEMP TABLE catalog_membership_before_publish ON COMMIT DROP AS
  SELECT
    cycles.id AS user_program_id,
    cycles.workout_program_id AS program_id,
    cycles.current_training_week,
    membership.workout_id,
    membership.position IS NOT NULL AS was_active
  FROM public.user_programs AS cycles
  JOIN public.program_workouts AS membership
    ON membership.program_id = cycles.workout_program_id;

  publication_result := public.publish_catalog_catalog_only(
    expected_backend_fingerprint,
    incoming_publication_id,
    incoming_source_fingerprint,
    incoming_source
  );

  -- Close removed workout periods before opening periods for newly active days.
  UPDATE public.user_program_workout_periods AS periods
  SET ends_week = before_publish.current_training_week - 1
  FROM catalog_membership_before_publish AS before_publish
  JOIN public.program_workouts AS membership
    ON membership.program_id = before_publish.program_id
   AND membership.workout_id = before_publish.workout_id
  WHERE before_publish.was_active
    AND membership.position IS NULL
    AND periods.user_program_id = before_publish.user_program_id
    AND periods.workout_id = before_publish.workout_id
    AND periods.ends_week IS NULL
    AND periods.starts_week < before_publish.current_training_week;

  DELETE FROM public.user_program_workout_periods AS periods
  USING catalog_membership_before_publish AS before_publish
  JOIN public.program_workouts AS membership
    ON membership.program_id = before_publish.program_id
   AND membership.workout_id = before_publish.workout_id
  WHERE before_publish.was_active
    AND membership.position IS NULL
    AND periods.user_program_id = before_publish.user_program_id
    AND periods.workout_id = before_publish.workout_id
    AND periods.ends_week IS NULL
    AND periods.starts_week >= before_publish.current_training_week;

  INSERT INTO public.user_program_workout_periods (
    user_program_id, workout_id, starts_week
  )
  SELECT
    cycle.user_program_id,
    before_publish.workout_id,
    cycle.current_training_week
  FROM catalog_cycles_before_publish AS cycle
  JOIN public.program_workouts AS membership
    ON membership.program_id = cycle.program_id
   AND membership.position IS NOT NULL
  JOIN catalog_membership_before_publish AS before_publish
    ON before_publish.user_program_id = cycle.user_program_id
   AND before_publish.workout_id = membership.workout_id
  WHERE NOT before_publish.was_active
  UNION ALL
  SELECT
    cycle.user_program_id,
    membership.workout_id,
    cycle.current_training_week
  FROM catalog_cycles_before_publish AS cycle
  JOIN public.program_workouts AS membership
    ON membership.program_id = cycle.program_id
   AND membership.position IS NOT NULL
  WHERE NOT EXISTS (
    SELECT 1
    FROM catalog_membership_before_publish AS before_publish
    WHERE before_publish.user_program_id = cycle.user_program_id
      AND before_publish.workout_id = membership.workout_id
      AND before_publish.was_active
  )
  ON CONFLICT (user_program_id, workout_id, starts_week) DO NOTHING;

  RETURN publication_result;
END;
$$;

COMMIT;
