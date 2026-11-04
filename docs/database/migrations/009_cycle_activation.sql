BEGIN;

-- Serialize selection with creation and other activations for this account.
CREATE FUNCTION public.activate_program_cycle(account_subject text, cycle uuid)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  account public.users%ROWTYPE;
  target public.user_programs%ROWTYPE;
  latest uuid;
BEGIN
  SELECT * INTO account FROM public.users WHERE clerk_user_id = account_subject FOR UPDATE;
  IF NOT FOUND OR account.active_user_program_id IS NULL THEN RETURN 'forbidden'; END IF;
  SELECT * INTO target FROM public.user_programs WHERE id = cycle AND user_id = account.id;
  IF NOT FOUND THEN RETURN 'forbidden'; END IF;
  PERFORM 1 FROM public.workout_programs WHERE id = target.workout_program_id AND is_offered FOR SHARE;
  IF NOT FOUND THEN RETURN 'unavailable'; END IF;
  SELECT id INTO latest FROM public.user_programs
    WHERE user_id = account.id AND workout_program_id = target.workout_program_id
    ORDER BY started_at DESC, id DESC LIMIT 1;
  IF latest <> cycle THEN RETURN 'conflict'; END IF;
  UPDATE public.users SET active_user_program_id = cycle WHERE id = account.id;
  RETURN 'activated';
END;
$$;

COMMIT;
