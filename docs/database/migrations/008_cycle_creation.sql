BEGIN;

-- Serialize creation with all selection commands for this account. An equal retry
-- acknowledges the original cycle without making it current again.
CREATE FUNCTION public.create_program_cycle(
  account_subject text, requested_program text, cycle uuid, cycle_started_at timestamptz, preferences jsonb
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  account public.users%ROWTYPE;
  existing public.user_programs%ROWTYPE;
  program integer;
BEGIN
  SELECT * INTO account FROM public.users WHERE clerk_user_id = account_subject FOR UPDATE;
  IF NOT FOUND OR account.active_user_program_id IS NULL THEN RETURN 'setup_required'; END IF;
  SELECT * INTO existing FROM public.user_programs WHERE id = cycle;
  IF FOUND THEN
    IF existing.user_id <> account.id THEN RETURN 'forbidden'; END IF;
    IF existing.started_at = cycle_started_at AND EXISTS (
      SELECT 1 FROM public.workout_programs WHERE id = existing.workout_program_id AND authoring_key = requested_program
    ) THEN RETURN 'acknowledged'; END IF;
    RETURN 'conflict';
  END IF;
  SELECT id INTO program FROM public.workout_programs
    WHERE authoring_key = requested_program AND is_offered FOR SHARE;
  IF NOT FOUND THEN RETURN 'unavailable'; END IF;
  IF EXISTS (SELECT 1 FROM public.user_programs WHERE user_id = account.id AND workout_program_id = program) THEN
    RETURN 'conflict';
  END IF;
  IF preferences <> 'null'::jsonb AND (
    EXISTS (SELECT 1 FROM jsonb_array_elements(preferences) item
      LEFT JOIN public.workout_exercises slot ON slot.authoring_key = item->>'workout_exercise_id'
      LEFT JOIN public.program_workouts membership ON membership.program_id = program
        AND membership.workout_id = slot.workout_id AND membership.position IS NOT NULL
      LEFT JOIN public.exercises replacement ON replacement.authoring_key = item->>'exercise_id'
      WHERE slot.id IS NULL OR slot.position IS NULL OR membership.workout_id IS NULL
        OR (item->>'exercise_id' IS NOT NULL AND replacement.id IS NULL))
    OR (SELECT count(*) FROM jsonb_array_elements(preferences)) <>
      (SELECT count(DISTINCT item->>'workout_exercise_id') FROM jsonb_array_elements(preferences) item)
  ) THEN RETURN 'invalid'; END IF;
  INSERT INTO public.user_programs (id, user_id, workout_program_id, started_at)
    VALUES (cycle, account.id, program, cycle_started_at);
  IF preferences = 'null'::jsonb THEN
    INSERT INTO public.user_workout_exercises (user_program_id, workout_exercise_id, exercise_id, note, rest_seconds)
      SELECT cycle, saved.workout_exercise_id, saved.exercise_id, saved.note, saved.rest_seconds
      FROM public.user_workout_exercises saved
      JOIN public.workout_exercises slot ON slot.id = saved.workout_exercise_id AND slot.position IS NOT NULL
      JOIN public.program_workouts membership ON membership.program_id = program AND membership.workout_id = slot.workout_id AND membership.position IS NOT NULL
      WHERE saved.user_program_id = account.active_user_program_id;
  ELSE
    INSERT INTO public.user_workout_exercises (user_program_id, workout_exercise_id, exercise_id, note, rest_seconds)
      SELECT cycle, slot.id, replacement.id, item->>'note', (item->>'rest_seconds')::integer
      FROM jsonb_array_elements(preferences) item
      JOIN public.workout_exercises slot ON slot.authoring_key = item->>'workout_exercise_id'
      LEFT JOIN public.exercises replacement ON replacement.authoring_key = item->>'exercise_id';
  END IF;
  UPDATE public.users SET active_user_program_id = cycle WHERE id = account.id;
  RETURN 'created';
EXCEPTION WHEN unique_violation THEN
  RETURN 'forbidden';
END;
$$;

COMMIT;
