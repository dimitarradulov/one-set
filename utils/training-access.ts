import type { Href } from 'expo-router';

import { TRAINING_ACCESS_STEPS } from '@/constants/training-access';
import type {
  TrainingAccessState,
  TrainingAccessStep,
  TrainingAccessStepId,
} from '@/types/training-access';

export const getTrainingAccessStep = (stepId: TrainingAccessStepId): TrainingAccessStep =>
  TRAINING_ACCESS_STEPS[stepId];

export const getStartTrainingHref = (state: TrainingAccessState): Href => {
  if (!state.isAuthenticated) {
    return '/create-account';
  }

  if (!state.hasTrainingAccess) {
    return '/trial-paywall';
  }

  if (!state.hasAcceptedFitnessDisclaimer) {
    return '/fitness-disclaimer';
  }

  return '/workout/session-a';
};
