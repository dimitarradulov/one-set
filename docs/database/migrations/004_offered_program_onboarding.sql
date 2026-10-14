BEGIN;

-- Reject stale-client enrollment atomically with the cycle creation. Existing
-- completed setup remains authoritative even when its program is later removed.
DROP FUNCTION public.complete_onboarding(text, public.weight_unit, integer, integer, uuid);

CREATE FUNCTION public.complete_onboarding(
  account_subject text, unit public.weight_unit, days integer,
  requested_program integer, cycle uuid
) RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  account public.users%ROWTYPE;
  offered_program integer;
BEGIN
  INSERT INTO public.users (clerk_user_id, preferred_unit, training_days)
  VALUES (account_subject, 'kg', 3)
  ON CONFLICT (clerk_user_id) DO NOTHING;

  SELECT * INTO STRICT account FROM public.users
  WHERE clerk_user_id = account_subject FOR UPDATE;

  IF account.active_user_program_id IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.user_programs WHERE user_id = account.id) THEN
    RETURN true;
  END IF;

  SELECT id INTO offered_program FROM public.workout_programs
  WHERE id = requested_program AND is_offered = true FOR SHARE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  INSERT INTO public.user_programs (id, user_id, workout_program_id, started_at)
  VALUES (cycle, account.id, offered_program, now());
  UPDATE public.users SET preferred_unit = unit, training_days = days,
    active_user_program_id = cycle WHERE id = account.id;
  RETURN true;
END;
$$;

COMMIT;
