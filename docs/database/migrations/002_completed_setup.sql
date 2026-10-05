BEGIN;

-- Identity is derived from a verified Clerk token by the Worker. One account-row
-- lock serializes first completion; retries never activate or change existing cycles.
CREATE FUNCTION public.complete_onboarding(
  account_subject text, unit public.weight_unit, days integer,
  program integer, cycle uuid
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  account public.users%ROWTYPE;
BEGIN
  INSERT INTO public.users (clerk_user_id, preferred_unit, training_days)
  VALUES (account_subject, 'kg', 3)
  ON CONFLICT (clerk_user_id) DO NOTHING;

  SELECT * INTO STRICT account FROM public.users
  WHERE clerk_user_id = account_subject FOR UPDATE;

  IF account.active_user_program_id IS NOT NULL
    OR EXISTS (SELECT 1 FROM public.user_programs WHERE user_id = account.id) THEN
    RETURN;
  END IF;

  INSERT INTO public.user_programs (id, user_id, workout_program_id, started_at)
  VALUES (cycle, account.id, program, now());
  UPDATE public.users SET preferred_unit = unit, training_days = days,
    active_user_program_id = cycle WHERE id = account.id;
END;
$$;

COMMIT;
