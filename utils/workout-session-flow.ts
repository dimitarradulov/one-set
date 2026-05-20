import type { Href } from 'expo-router';

export const PREVIEW_SESSION_ID = 'session-a';
export const PREVIEW_FIRST_EXERCISE_ID = '1';

export type WorkoutSessionParams = {
  sessionId: string;
};

export type WorkoutExerciseParams = WorkoutSessionParams & {
  exerciseId: string;
};

export type WorkoutSessionLink = {
  href: Href;
  label: string;
};

export const getWorkoutOverviewLinks = ({ sessionId }: WorkoutSessionParams) => ({
  primary: {
    href: `/workout/${sessionId}/exercise/${PREVIEW_FIRST_EXERCISE_ID}` as Href,
    label: 'Start Exercise 1',
  },
  secondary: {
    href: '/(tabs)/program' as Href,
    label: 'Back to Program',
  },
});

export const getActiveExerciseLinks = ({ sessionId, exerciseId }: WorkoutExerciseParams) => ({
  primary: {
    href: `/workout/${sessionId}/rest/${exerciseId}` as Href,
    label: 'Complete Set and Start Rest',
  },
  secondary: {
    href: `/workout/${sessionId}` as Href,
    label: 'Back to Workout Overview',
  },
});

export const getRestTimerLinks = ({ sessionId, exerciseId }: WorkoutExerciseParams) => {
  const currentExerciseNumber = Number.parseInt(exerciseId, 10);
  const nextExerciseId = Number.isFinite(currentExerciseNumber)
    ? String(currentExerciseNumber + 1)
    : PREVIEW_FIRST_EXERCISE_ID;

  return {
    primary: {
      href: `/workout/${sessionId}/exercise/${nextExerciseId}` as Href,
      label: `Continue to Exercise ${nextExerciseId}`,
    },
    secondary: {
      href: `/workout/${sessionId}/summary` as Href,
      label: 'Finish Workout',
    },
  };
};

export const getWorkoutSummaryLinks = () => ({
  primary: {
    href: '/(tabs)' as Href,
    label: 'Back to Home',
  },
  secondary: {
    href: '/(tabs)/logbook' as Href,
    label: 'Back to Logbook',
  },
});

export const getPreviewWorkoutHref = (): Href => `/workout/${PREVIEW_SESSION_ID}` as Href;

export const getPreviewExerciseHref = (): Href =>
  `/workout/${PREVIEW_SESSION_ID}/exercise/${PREVIEW_FIRST_EXERCISE_ID}` as Href;

export const getPreviewWorkoutSummaryHref = (): Href =>
  `/workout/${PREVIEW_SESSION_ID}/summary` as Href;
