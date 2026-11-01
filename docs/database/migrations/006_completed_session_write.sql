BEGIN;

-- Save a finished, device-authored session and its occurrence completion as one
-- owner-scoped command. The client never supplies an owner or database IDs.
CREATE FUNCTION public.save_completed_session(
  authenticated_clerk_user_id text,
  payload jsonb
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_user_id integer;
  v_cycle_id uuid;
  v_cycle_user_id integer;
  v_cycle_program_id integer;
  v_current_week integer;
  v_program_id integer;
  v_workout_id integer;
  v_session_id uuid;
  v_week integer;
  v_started_at timestamptz;
  v_completed_at timestamptz;
  v_set jsonb;
  v_slot_id integer;
  v_exercise_id integer;
  v_position integer;
  v_weight numeric;
  v_reps integer;
  v_unit public.weight_unit;
  v_set_completed_at timestamptz;
  v_set_count integer;
  v_distinct_slot_count integer;
  v_distinct_position_count integer;
  v_has_completed_set boolean := false;
  v_existing public.workout_sessions%ROWTYPE;
  v_existing_owner integer;
  v_mismatch boolean := false;
  v_existing_set public.workout_session_sets%ROWTYPE;
  v_existing_count integer;
  v_required_count integer;
  v_completed_count integer;
BEGIN
  IF jsonb_typeof(payload) <> 'object'
    OR payload ? 'user_id'
    OR payload ? 'owner_id'
    OR jsonb_typeof(payload->'sets') <> 'array'
    OR jsonb_array_length(payload->'sets') < 1
    OR jsonb_array_length(payload->'sets') > 100 THEN
    RETURN 'invalid_session';
  END IF;

  v_session_id := (payload->>'session_id')::uuid;
  v_cycle_id := (payload->>'cycle_id')::uuid;
  v_week := (payload->>'week_number')::integer;
  v_started_at := (payload->>'started_at')::timestamptz;
  v_completed_at := (payload->>'completed_at')::timestamptz;
  IF v_week <= 0 OR v_completed_at < v_started_at
    OR length(btrim(payload->>'workout_name')) = 0
    OR length(payload->>'workout_name') > 300
    OR length(coalesce(payload->>'note', '')) > 4000 THEN
    RETURN 'invalid_session';
  END IF;

  SELECT count(*)::integer,
    count(DISTINCT item->>'workout_exercise_key')::integer,
    count(DISTINCT (item->>'position')::integer)::integer
  INTO v_set_count, v_distinct_slot_count, v_distinct_position_count
  FROM jsonb_array_elements(payload->'sets') AS item;
  IF v_set_count <> v_distinct_slot_count OR v_set_count <> v_distinct_position_count THEN
    RETURN 'invalid_session';
  END IF;

  -- Catalog publication takes this lock first. The shared lock keeps all key
  -- resolution below on one published structure while allowing other finishes.
  PERFORM 1 FROM public.catalog_state WHERE singleton = true FOR SHARE;
  IF NOT FOUND THEN RETURN 'invalid_session'; END IF;

  -- Lock order is catalog state, user, then cycle. It matches catalog writes
  -- and serializes session creation/progress for one account.
  SELECT id INTO v_user_id
  FROM public.users WHERE clerk_user_id = authenticated_clerk_user_id FOR UPDATE;
  IF NOT FOUND THEN RETURN 'cycle_forbidden'; END IF;

  SELECT cycle.user_id, cycle.workout_program_id, cycle.current_training_week
  INTO v_cycle_user_id, v_cycle_program_id, v_current_week
  FROM public.user_programs AS cycle
  WHERE cycle.id = v_cycle_id FOR UPDATE;
  IF NOT FOUND OR v_cycle_user_id <> v_user_id THEN RETURN 'cycle_forbidden'; END IF;

  SELECT id INTO v_program_id FROM public.workout_programs
  WHERE authoring_key = payload->>'program_key';
  IF NOT FOUND OR v_program_id <> v_cycle_program_id THEN RETURN 'invalid_session'; END IF;

  SELECT workout.id INTO v_workout_id
  FROM public.workouts AS workout
  JOIN public.program_workouts AS membership ON membership.workout_id = workout.id
  WHERE membership.program_id = v_program_id
    AND workout.authoring_key = payload->>'workout_key';
  IF NOT FOUND OR NOT EXISTS (
    SELECT 1 FROM public.user_program_workout_periods AS period
    WHERE period.user_program_id = v_cycle_id
      AND period.workout_id = v_workout_id
      AND v_week >= period.starts_week
      AND (period.ends_week IS NULL OR v_week <= period.ends_week)
  ) THEN RETURN 'invalid_session'; END IF;

  -- Validate every captured slot and value before inserting any training rows.
  -- Captured guidance, slot order, and prescription are deliberately not compared
  -- with today's catalog document.
  FOR v_set IN SELECT value FROM jsonb_array_elements(payload->'sets') AS rows(value) LOOP
    SELECT slot.id INTO v_slot_id
    FROM public.workout_exercises AS slot
    WHERE slot.workout_id = v_workout_id
      AND slot.authoring_key = v_set->>'workout_exercise_key';
    IF NOT FOUND THEN RETURN 'invalid_session'; END IF;

    SELECT exercise.id INTO v_exercise_id FROM public.exercises AS exercise
    WHERE exercise.authoring_key = v_set->>'exercise_key';
    IF NOT FOUND THEN RETURN 'invalid_session'; END IF;

    IF jsonb_typeof(v_set->'position') <> 'number'
      OR (v_set->>'position')::integer <= 0
      OR jsonb_typeof(v_set->'prescription') <> 'object'
      OR length(btrim(v_set->'prescription'->>'name')) = 0
      OR length(btrim(v_set->'prescription'->>'instructions')) = 0
      OR length(btrim(v_set->'prescription'->>'stopping_guidance')) = 0
      OR jsonb_typeof(v_set->'prescription'->'warmup_guidance') <> 'object'
      OR jsonb_typeof(v_set->'prescription'->'warmup_guidance'->'steps') <> 'array'
      OR jsonb_typeof(v_set->'prescription'->'warmup_guidance'->'note') <> 'string'
      OR length(v_set->'prescription'->>'name') > 300
      OR length(v_set->'prescription'->>'instructions') > 4000
      OR length(v_set->'prescription'->>'stopping_guidance') > 2000
      OR length(v_set->'prescription'->'warmup_guidance'->>'note') > 2000
      OR (v_set->'prescription'->>'video_key' IS NOT NULL
        AND jsonb_typeof(v_set->'prescription'->'video_key') NOT IN ('string', 'null'))
      OR (v_set->'prescription'->>'reps_min')::integer <= 0
      OR (v_set->'prescription'->>'reps_max')::integer < (v_set->'prescription'->>'reps_min')::integer
      OR v_set->'prescription'->>'rep_scope' NOT IN ('reps', 'each_leg', 'each_side')
      OR (v_set->'prescription'->>'rest_seconds' IS NOT NULL
        AND (v_set->'prescription'->>'rest_seconds')::integer <= 0) THEN
      RETURN 'invalid_session';
    END IF;

    IF v_set->>'unit' NOT IN ('kg', 'lb') THEN RETURN 'invalid_session'; END IF;
    v_unit := (v_set->>'unit')::public.weight_unit;
    IF v_set->>'completed_at' IS NULL THEN
      IF v_set->>'weight' IS NOT NULL OR v_set->>'reps' IS NOT NULL THEN
        RETURN 'invalid_session';
      END IF;
      CONTINUE;
    END IF;

    v_set_completed_at := (v_set->>'completed_at')::timestamptz;
    v_weight := (v_set->>'weight')::numeric;
    v_reps := (v_set->>'reps')::integer;
    IF v_set_completed_at < v_started_at OR v_set_completed_at > v_completed_at
      OR v_weight < 0 OR v_weight > 9999999.999
      OR v_weight <> trunc(v_weight, 3) OR v_reps <= 0 THEN
      RETURN 'invalid_session';
    END IF;
    v_has_completed_set := true;
  END LOOP;
  IF NOT v_has_completed_set THEN RETURN 'invalid_session'; END IF;

  SELECT * INTO v_existing FROM public.workout_sessions
  WHERE id = v_session_id FOR UPDATE;
  IF FOUND THEN
    SELECT cycle.user_id INTO v_existing_owner
    FROM public.user_programs AS cycle
    WHERE cycle.id = v_existing.user_program_id;
    IF v_existing_owner IS DISTINCT FROM v_user_id
      OR v_existing.user_program_id IS DISTINCT FROM v_cycle_id
      OR v_existing.workout_id IS DISTINCT FROM v_workout_id
      OR v_existing.week_number IS DISTINCT FROM v_week
      OR v_existing.workout_name IS DISTINCT FROM payload->>'workout_name'
      OR v_existing.started_at IS DISTINCT FROM v_started_at
      OR v_existing.completed_at IS DISTINCT FROM v_completed_at
      OR v_existing.note IS DISTINCT FROM nullif(payload->>'note', '') THEN
      RETURN 'session_conflict';
    END IF;

    FOR v_set IN SELECT value FROM jsonb_array_elements(payload->'sets') AS rows(value) LOOP
      SELECT slot.id INTO v_slot_id FROM public.workout_exercises AS slot
      WHERE slot.workout_id = v_workout_id
        AND slot.authoring_key = v_set->>'workout_exercise_key';
      SELECT exercise.id INTO v_exercise_id FROM public.exercises AS exercise
      WHERE exercise.authoring_key = v_set->>'exercise_key';
      SELECT * INTO v_existing_set FROM public.workout_session_sets AS set_row
      WHERE set_row.workout_session_id = v_session_id
        AND set_row.workout_exercise_id = v_slot_id;
      IF NOT FOUND
        OR v_existing_set.position IS DISTINCT FROM (v_set->>'position')::integer
        OR v_existing_set.exercise_id IS DISTINCT FROM v_exercise_id
        OR v_existing_set.prescription IS DISTINCT FROM v_set->'prescription'
        OR v_existing_set.note IS NOT NULL
        OR v_existing_set.weight IS DISTINCT FROM (v_set->>'weight')::numeric
        OR v_existing_set.unit IS DISTINCT FROM (v_set->>'unit')::public.weight_unit
        OR v_existing_set.reps IS DISTINCT FROM (v_set->>'reps')::integer
        OR v_existing_set.completed_at IS DISTINCT FROM (v_set->>'completed_at')::timestamptz THEN
        v_mismatch := true;
        EXIT;
      END IF;
    END LOOP;
    SELECT count(*)::integer INTO v_existing_count FROM public.workout_session_sets
    WHERE workout_session_id = v_session_id;
    IF v_mismatch OR v_existing_count <> v_set_count OR v_existing.completed_at IS NULL THEN
      RETURN 'session_conflict';
    END IF;
    RETURN 'acknowledged';
  END IF;

  INSERT INTO public.workout_sessions (
    id, user_program_id, workout_id, week_number, workout_name, started_at, completed_at, note
  ) VALUES (
    v_session_id, v_cycle_id, v_workout_id, v_week, payload->>'workout_name',
    v_started_at, v_completed_at, nullif(payload->>'note', '')
  );

  FOR v_set IN SELECT value FROM jsonb_array_elements(payload->'sets') AS rows(value) LOOP
    SELECT slot.id INTO v_slot_id FROM public.workout_exercises AS slot
    WHERE slot.workout_id = v_workout_id
      AND slot.authoring_key = v_set->>'workout_exercise_key';
    SELECT exercise.id INTO v_exercise_id FROM public.exercises AS exercise
    WHERE exercise.authoring_key = v_set->>'exercise_key';
    INSERT INTO public.workout_session_sets (
      workout_session_id, position, workout_exercise_id, exercise_id, prescription,
      note, weight, unit, reps, completed_at
    ) VALUES (
      v_session_id, (v_set->>'position')::integer, v_slot_id, v_exercise_id,
      v_set->'prescription', NULL, (v_set->>'weight')::numeric,
      (v_set->>'unit')::public.weight_unit, (v_set->>'reps')::integer,
      (v_set->>'completed_at')::timestamptz
    );
  END LOOP;

  INSERT INTO public.completed_workouts (user_program_id, week_number, workout_id)
  VALUES (v_cycle_id, v_week, v_workout_id)
  ON CONFLICT (user_program_id, week_number, workout_id) DO NOTHING;

  -- Move forward only when every workout required for the current week has a
  -- completion mark. Existing marks may let one new write advance several weeks.
  LOOP
    SELECT count(*)::integer, count(mark.workout_id)::integer
    INTO v_required_count, v_completed_count
    FROM public.required_workouts_for_cycle_week(v_cycle_id, v_current_week) AS required
    LEFT JOIN public.completed_workouts AS mark
      ON mark.user_program_id = v_cycle_id
     AND mark.week_number = v_current_week
     AND mark.workout_id = required.workout_id;
    EXIT WHEN v_required_count = 0 OR v_completed_count <> v_required_count;
    v_current_week := v_current_week + 1;
    UPDATE public.user_programs SET current_training_week = v_current_week
    WHERE id = v_cycle_id;
  END LOOP;

  RETURN 'created';
EXCEPTION
  WHEN unique_violation THEN RETURN 'session_conflict';
END;
$$;

COMMIT;
