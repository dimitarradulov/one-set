import type { Href } from 'expo-router';

export type TrainingAccessState = {
  isAuthenticated: boolean;
  hasTrainingAccess: boolean;
  hasAcceptedFitnessDisclaimer: boolean;
};

export type TrainingAccessStepId =
  | 'program-preview'
  | 'create-account'
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
