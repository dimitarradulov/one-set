BEGIN;

ALTER TABLE public.program_workouts
  ADD COLUMN week_parity text CHECK (week_parity IN ('odd', 'even'));

-- Apply the schedule in the same transaction as membership and periods.
ALTER FUNCTION public.publish_catalog(text, text, text, jsonb)
  RENAME TO publish_catalog_with_workout_periods;

CREATE FUNCTION public.publish_catalog(
  expected_backend_fingerprint text,
  incoming_publication_id text,
  incoming_source_fingerprint text,
  incoming_source jsonb
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  publication_result text;
BEGIN
  publication_result := public.publish_catalog_with_workout_periods(
    expected_backend_fingerprint, incoming_publication_id, incoming_source_fingerprint, incoming_source
  );

  -- Retrying a superseded publication must leave the current schedule intact.
  IF EXISTS (
    SELECT 1 FROM public.catalog_state
    WHERE singleton = true AND publication_id = publication_result
  ) THEN
    UPDATE public.program_workouts AS membership
    SET week_parity = workout_doc->>'week_parity'
    FROM jsonb_array_elements(incoming_source->'programs') AS program_doc
    CROSS JOIN LATERAL jsonb_array_elements(program_doc->'workouts') AS workout_doc
    JOIN public.workouts AS workout ON workout.authoring_key = workout_doc->>'key'
    JOIN public.workout_programs AS program ON true
    WHERE program.authoring_key = program_doc->>'key'
      AND membership.program_id = program.id
      AND membership.workout_id = workout.id
      AND membership.week_parity IS DISTINCT FROM workout_doc->>'week_parity';
  END IF;

  RETURN publication_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.required_workouts_for_cycle_week(
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
    AND (membership.week_parity IS NULL
      OR membership.week_parity = CASE WHEN target_week % 2 = 0 THEN 'even' ELSE 'odd' END)
  ORDER BY membership.position;
$$;

ALTER FUNCTION public.save_completed_session_with_day(text, jsonb)
  RENAME TO save_completed_session_with_historical_day;

CREATE FUNCTION public.save_completed_session_with_day(
  authenticated_clerk_user_id text,
  payload jsonb
) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  -- Match the lock order of session writes and catalog publication.
  PERFORM 1 FROM public.catalog_state WHERE singleton = true FOR SHARE;
  IF EXISTS (
    SELECT 1
    FROM public.program_workouts AS membership
    JOIN public.workout_programs AS program ON program.id = membership.program_id
    JOIN public.workouts AS workout ON workout.id = membership.workout_id
    WHERE program.authoring_key = payload->>'program_key'
      AND workout.authoring_key = payload->>'workout_key'
      AND membership.week_parity <> CASE WHEN (payload->>'week_number')::integer % 2 = 0 THEN 'even' ELSE 'odd' END
  ) THEN
    RETURN 'invalid_session';
  END IF;
  RETURN public.save_completed_session_with_historical_day(authenticated_clerk_user_id, payload);
END;
$$;

COMMIT;
