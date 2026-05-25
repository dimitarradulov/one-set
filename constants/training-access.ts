import type {
  TrainingAccessState,
  TrainingAccessStep,
  TrainingAccessStepId,
} from '@/types/training-access';

export const PREVIEW_TRAINING_ACCESS_STATE: TrainingAccessState = {
  isAuthenticated: false,
  hasTrainingAccess: false,
  hasAcceptedFitnessDisclaimer: false,
};

export const TRAINING_ACCESS_STEPS = {
  'program-preview': {
    title: 'Program Preview',
    description: 'Preview route before entering the focused workout flow.',
    primaryHref: '/create-account',
    primaryLabel: 'Start Focused Session Preview',
  },
  'create-account': {
    title: 'Account Creation Prompt',
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
    secondaryHref: '/create-account',
    secondaryLabel: 'Back to Create Account',
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
