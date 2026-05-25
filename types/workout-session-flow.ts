import type { Href } from 'expo-router';

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
