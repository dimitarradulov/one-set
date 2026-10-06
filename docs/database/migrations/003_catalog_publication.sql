BEGIN;

-- Stable authoring identities preserve existing numeric references and let later
-- programs publish without a per-environment deployment map.
ALTER TABLE public.workout_programs
  ADD COLUMN authoring_key text,
  ADD COLUMN is_offered boolean NOT NULL DEFAULT true;
ALTER TABLE public.workouts ADD COLUMN authoring_key text;
ALTER TABLE public.exercises ADD COLUMN authoring_key text;
ALTER TABLE public.workout_exercises ADD COLUMN authoring_key text;
ALTER TABLE public.workout_exercises ADD COLUMN rep_scope text NOT NULL DEFAULT 'reps'
  CHECK (rep_scope IN ('reps', 'each_leg', 'each_side'));

UPDATE public.workout_programs AS programs
SET authoring_key = identities.authoring_key
FROM (VALUES
  (1, 'full-body'),
  (2, 'upper-lower'),
  (3, 'push-pull-legs'),
  (4, 'bro-split'),
  (5, 'minimalist-full-body'),
  (6, 'v-taper'),
  (7, 'powerhouse'),
  (8, 'classic-physique'),
  (9, 'free-weight-full-body'),
  (10, 'machine-full-body')
) AS identities(id, authoring_key)
WHERE programs.id = identities.id AND programs.authoring_key IS NULL;

CREATE UNIQUE INDEX workout_programs_authoring_key_idx
  ON public.workout_programs (authoring_key);
CREATE UNIQUE INDEX workouts_authoring_key_idx
  ON public.workouts (authoring_key);
CREATE UNIQUE INDEX exercises_authoring_key_idx
  ON public.exercises (authoring_key);
CREATE UNIQUE INDEX workout_exercises_authoring_key_idx
  ON public.workout_exercises (authoring_key);

CREATE TABLE public.catalog_publications (
  id text PRIMARY KEY,
  source_fingerprint text NOT NULL,
  backend_fingerprint text NOT NULL,
  source_document jsonb NOT NULL CHECK (jsonb_typeof(source_document) = 'object'),
  published_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.catalog_state (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  publication_id text REFERENCES public.catalog_publications(id),
  source_fingerprint text,
  source_document jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((publication_id IS NULL) = (source_fingerprint IS NULL)),
  CHECK ((publication_id IS NULL) = (source_document IS NULL))
);
INSERT INTO public.catalog_state (singleton) VALUES (true);

CREATE FUNCTION public.publish_catalog(
  expected_backend_fingerprint text,
  incoming_publication_id text,
  incoming_source_fingerprint text,
  incoming_source jsonb
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  current_state public.catalog_state%ROWTYPE;
  previous_publication public.catalog_publications%ROWTYPE;
  program_doc jsonb;
  workout_doc jsonb;
  slot_doc jsonb;
  exercise_doc jsonb;
  v_program_id integer;
  v_workout_id integer;
  v_exercise_id integer;
  old_exercise_key text;
  old_workout_key text;
  saved_publication_id text;
BEGIN
  SELECT * INTO STRICT current_state FROM public.catalog_state
  WHERE singleton = true FOR UPDATE;

  SELECT * INTO previous_publication FROM public.catalog_publications
  WHERE id = incoming_publication_id;
  IF FOUND THEN
    IF previous_publication.source_fingerprint <> incoming_source_fingerprint
       OR previous_publication.source_document <> incoming_source THEN
      RAISE EXCEPTION USING MESSAGE = 'PUBLICATION_RETRY_MISMATCH', ERRCODE = '22000';
    END IF;
    RETURN previous_publication.id;
  END IF;

  IF coalesce(current_state.source_fingerprint, 'empty') <> expected_backend_fingerprint THEN
    RAISE EXCEPTION USING MESSAGE = 'STALE_PREVIEW', ERRCODE = '40001';
  END IF;

  -- A stable slot key cannot silently begin prescribing a different movement.
  FOR program_doc IN SELECT value FROM jsonb_array_elements(incoming_source->'programs') LOOP
    FOR workout_doc IN SELECT value FROM jsonb_array_elements(program_doc->'workouts') LOOP
      FOR slot_doc IN SELECT value FROM jsonb_array_elements(workout_doc->'exercises') LOOP
        SELECT old_exercise.authoring_key, old_workout.authoring_key
        INTO old_exercise_key, old_workout_key
        FROM public.workout_exercises old_slot
        JOIN public.exercises old_exercise ON old_exercise.id = old_slot.exercise_id
        JOIN public.workouts old_workout ON old_workout.id = old_slot.workout_id
        WHERE old_slot.authoring_key = slot_doc->>'key';
        IF FOUND AND (old_exercise_key <> slot_doc->>'exercise'
                      OR old_workout_key <> workout_doc->>'key') THEN
          RAISE EXCEPTION USING MESSAGE = 'SLOT_IDENTITY_REPURPOSED', ERRCODE = '22000';
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  FOR exercise_doc IN SELECT value FROM jsonb_array_elements(incoming_source->'exercises') LOOP
    INSERT INTO public.exercises (
      authoring_key, name, instructions, video_key, reps_min, reps_max,
      rest_seconds, warmup_guidance
    ) VALUES (
      exercise_doc->>'key', exercise_doc->>'name', exercise_doc->>'instructions',
      nullif(exercise_doc->>'video_key', ''),
      (exercise_doc->'default_reps'->>'minimum')::integer,
      (exercise_doc->'default_reps'->>'maximum')::integer,
      (exercise_doc->>'rest_seconds')::integer,
      jsonb_build_object('steps', '[]'::jsonb, 'note', exercise_doc->>'warmup_guidance')
    )
    ON CONFLICT (authoring_key) DO UPDATE SET
      name = EXCLUDED.name,
      instructions = EXCLUDED.instructions,
      video_key = EXCLUDED.video_key,
      reps_min = EXCLUDED.reps_min,
      reps_max = EXCLUDED.reps_max,
      rest_seconds = EXCLUDED.rest_seconds,
      warmup_guidance = EXCLUDED.warmup_guidance;
  END LOOP;

  FOR program_doc IN SELECT value FROM jsonb_array_elements(incoming_source->'programs') LOOP
    INSERT INTO public.workout_programs (authoring_key, name, recommended_weeks, is_offered)
    VALUES (program_doc->>'key', program_doc->>'name',
      (program_doc->>'recommended_weeks')::integer,
      NOT coalesce((program_doc->>'removed')::boolean, false))
    ON CONFLICT (authoring_key) DO UPDATE SET
      name = EXCLUDED.name,
      recommended_weeks = EXCLUDED.recommended_weeks,
      is_offered = EXCLUDED.is_offered
    RETURNING id INTO v_program_id;

    UPDATE public.program_workouts SET position = NULL WHERE program_workouts.program_id = v_program_id;

    FOR workout_doc IN SELECT value FROM jsonb_array_elements(program_doc->'workouts') LOOP
      INSERT INTO public.workouts (authoring_key, name)
      VALUES (workout_doc->>'key', workout_doc->>'name')
      ON CONFLICT (authoring_key) DO UPDATE SET name = EXCLUDED.name
      RETURNING id INTO v_workout_id;

      UPDATE public.workout_exercises SET position = NULL WHERE workout_exercises.workout_id = v_workout_id;

      INSERT INTO public.program_workouts (program_id, workout_id, position)
      VALUES (v_program_id, v_workout_id,
        CASE WHEN coalesce((workout_doc->>'removed')::boolean, false)
             THEN NULL ELSE (workout_doc->>'position')::integer END)
      ON CONFLICT (program_id, workout_id) DO UPDATE SET position = EXCLUDED.position;

      FOR slot_doc IN SELECT value FROM jsonb_array_elements(workout_doc->'exercises') LOOP
        SELECT id INTO v_exercise_id FROM public.exercises WHERE authoring_key = slot_doc->>'exercise';
        INSERT INTO public.workout_exercises (
          authoring_key, workout_id, exercise_id, position, reps_min, reps_max, rep_scope
        ) VALUES (
          slot_doc->>'key', v_workout_id, v_exercise_id,
          CASE WHEN coalesce((slot_doc->>'removed')::boolean, false)
               THEN NULL ELSE (slot_doc->>'position')::integer END,
          (slot_doc->'reps'->>'minimum')::integer,
          (slot_doc->'reps'->>'maximum')::integer,
          coalesce(slot_doc->>'scope', 'reps')
        )
        ON CONFLICT (authoring_key) DO UPDATE SET
          workout_id = EXCLUDED.workout_id,
          exercise_id = EXCLUDED.exercise_id,
          position = EXCLUDED.position,
          reps_min = EXCLUDED.reps_min,
          reps_max = EXCLUDED.reps_max,
          rep_scope = EXCLUDED.rep_scope;
      END LOOP;
    END LOOP;
  END LOOP;

  INSERT INTO public.catalog_publications (
    id, source_fingerprint, backend_fingerprint, source_document
  ) VALUES (
    incoming_publication_id, incoming_source_fingerprint, expected_backend_fingerprint, incoming_source
  );
  UPDATE public.catalog_state SET
    publication_id = incoming_publication_id,
    source_fingerprint = incoming_source_fingerprint,
    source_document = incoming_source,
    updated_at = now()
  WHERE singleton = true;

  RETURN incoming_publication_id;
END;
$$;

COMMIT;
