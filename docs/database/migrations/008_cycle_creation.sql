BEGIN;

-- Serialize creation with all selection commands for this account. An equal retry
-- acknowledges the original cycle without making it current again.
CREATE FUNCTION public.create_program_cycle(
  account_subject text, requested_program text, cycle uuid, cycle_started_at timestamptz
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
  INSERT INTO public.user_programs (id, user_id, workout_program_id, started_at)
    VALUES (cycle, account.id, program, cycle_started_at);
  UPDATE public.users SET active_user_program_id = cycle WHERE id = account.id;
  RETURN 'created';
EXCEPTION WHEN unique_violation THEN
  RETURN 'forbidden';
END;
$$;

COMMIT;
