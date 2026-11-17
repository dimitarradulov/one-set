BEGIN;

CREATE FUNCTION public.prevent_cycle_program_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION USING MESSAGE = 'CYCLE_PROGRAM_IMMUTABLE', ERRCODE = '23514';
END;
$$;

CREATE TRIGGER user_programs_program_is_immutable
AFTER UPDATE ON public.user_programs
FOR EACH ROW WHEN (OLD.workout_program_id IS DISTINCT FROM NEW.workout_program_id)
EXECUTE FUNCTION public.prevent_cycle_program_change();

CREATE FUNCTION public.require_open_period_active_membership()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Keep the cycle identity stable and prevent changes to membership position.
  PERFORM 1
  FROM public.user_programs AS cycle
  JOIN public.program_workouts AS membership
    ON membership.program_id = cycle.workout_program_id
  WHERE cycle.id = NEW.user_program_id
    AND membership.workout_id = NEW.workout_id
    AND membership.position IS NOT NULL
  FOR KEY SHARE OF cycle
  FOR SHARE OF membership;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING MESSAGE = 'OPEN_WORKOUT_PERIOD_REQUIRES_ACTIVE_MEMBERSHIP', ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER cycle_workout_periods_require_active_membership
BEFORE INSERT OR UPDATE ON public.user_program_workout_periods
FOR EACH ROW WHEN (NEW.ends_week IS NULL)
EXECUTE FUNCTION public.require_open_period_active_membership();

COMMIT;
