import type { Href } from 'expo-router';

export type TrainingAccessState = {
  isAuthenticated: boolean;
  hasTrainingAccess: boolean;
  hasAcceptedFitnessDisclaimer: boolean;
};

export type TrainingAccessStepId =
  | 'program-preview'
  | 'auth-prompt'
  | 'trial-paywall'
  | 'disclaimer';

export type TrainingAccessStep = {
  title: string;
  description: string;
  primaryHref: Href;
  primaryLabel: string;
  secondaryHref?: Href;
  secondaryLabel?: string;
};

export const PREVIEW_TRAINING_ACCESS_STATE: TrainingAccessState = {
  isAuthenticated: false,
  hasTrainingAccess: false,
  hasAcceptedFitnessDisclaimer: false,
};

export const TRAINING_ACCESS_STEPS = {
  'program-preview': {
    title: 'Program Preview',
    description: 'Preview route before entering the focused workout flow.',
    primaryHref: '/auth-prompt',
    primaryLabel: 'Start Focused Session Preview',
  },
  'auth-prompt': {
    title: 'Auth Prompt',
    description: 'Create an account to save your progress.',
    primaryHref: '/trial-paywall',
    primaryLabel: 'Continue to Trial Paywall',
    secondaryHref: '/program-intro',
    secondaryLabel: 'Back to Program Preview',
  },
  'trial-paywall': {
    title: 'Trial Paywall',
    description: '14-day free trial plus subscription gate.',
    primaryHref: '/fitness-disclaimer',
    primaryLabel: 'Continue to Fitness Disclaimer',
    secondaryHref: '/auth-prompt',
    secondaryLabel: 'Back to Auth Prompt',
  },
  disclaimer: {
    title: 'Fitness Disclaimer',
    description: 'One-time legal and safety acknowledgment before real training starts.',
    primaryHref: '/workout/session-a',
    primaryLabel: 'Continue to Workout Overview',
    secondaryHref: '/trial-paywall',
    secondaryLabel: 'Back to Trial Paywall',
  },
} as const satisfies Record<TrainingAccessStepId, TrainingAccessStep>;

export const getTrainingAccessStep = (stepId: TrainingAccessStepId): TrainingAccessStep =>
  TRAINING_ACCESS_STEPS[stepId];

export const getStartTrainingHref = (state: TrainingAccessState): Href => {
  if (!state.isAuthenticated) {
    return '/auth-prompt';
  }

  if (!state.hasTrainingAccess) {
    return '/trial-paywall';
  }

  if (!state.hasAcceptedFitnessDisclaimer) {
    return '/fitness-disclaimer';
  }

  return '/workout/session-a';
};
