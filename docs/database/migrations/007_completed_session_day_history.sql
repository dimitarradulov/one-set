BEGIN;

-- Keep the original upload function intact. New app versions use this wrapper
-- to add trustworthy historical day context while older clients remain valid.
ALTER TABLE public.workout_sessions
  ADD COLUMN day_number integer CHECK (day_number IS NULL OR day_number > 0);

CREATE FUNCTION public.save_completed_session_with_day(
  authenticated_clerk_user_id text,
  payload jsonb
) RETURNS text LANGUAGE plpgsql AS $function$
DECLARE
  v_result text;
  v_session_id uuid;
  v_day_number integer;
  v_existing_day_number integer;
BEGIN
  IF payload ? 'day_number' AND jsonb_typeof(payload->'day_number') NOT IN ('number', 'null') THEN
    RETURN 'invalid_session';
  END IF;

  IF payload ? 'day_number' AND jsonb_typeof(payload->'day_number') = 'number' THEN
    v_day_number := (payload->>'day_number')::integer;
    IF v_day_number <= 0 OR v_day_number > 100
      OR (payload->>'day_number')::numeric <> v_day_number THEN
      RETURN 'invalid_session';
    END IF;
  END IF;

  v_result := public.save_completed_session(authenticated_clerk_user_id, payload);
  IF v_result NOT IN ('created', 'acknowledged') THEN
    RETURN v_result;
  END IF;

  v_session_id := (payload->>'session_id')::uuid;
  IF v_result = 'created' THEN
    UPDATE public.workout_sessions
      SET day_number = v_day_number
      WHERE id = v_session_id;
  ELSIF payload ? 'day_number' THEN
    SELECT session.day_number INTO v_existing_day_number
      FROM public.workout_sessions AS session
      JOIN public.user_programs AS cycle ON cycle.id = session.user_program_id
      JOIN public.users AS owner ON owner.id = cycle.user_id
      WHERE session.id = v_session_id
        AND owner.clerk_user_id = authenticated_clerk_user_id;
    IF v_existing_day_number IS DISTINCT FROM v_day_number THEN
      RETURN 'session_conflict';
    END IF;
  END IF;

  RETURN v_result;
EXCEPTION
  WHEN unique_violation THEN RETURN 'session_conflict';
END;
$function$;

COMMIT;
