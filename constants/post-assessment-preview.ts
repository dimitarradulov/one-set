import type {
  PostAssessmentPreviewStep,
  PostAssessmentPreviewStepId,
} from '@/types/post-assessment-preview';

export const POST_ASSESSMENT_STEPS = {
  'result-calculation': {
    title: 'Result Calculation',
    description: 'OneSet checks your complete Assessment Draft before matching a starter program.',
    nextHref: '/recommended-program',
    nextLabel: 'Next: Program Recommendation',
  },
  'recommended-program': {
    title: 'Program Recommendation',
    description:
      'Your Program Recommendation is pure preview state until training access is granted.',
    nextHref: '/create-account',
    nextLabel: 'Continue',
  },
  'hit-principles': {
    title: 'HIT Principles',
    description: 'Core high-intensity training principles before the first workout preview.',
    nextHref: '/first-workout-preview',
    nextLabel: 'Next: First Workout Preview',
  },
  'first-workout-preview': {
    title: 'First Workout Preview',
    description: 'A focused preview of the first training session before account and access gates.',
    nextHref: '/program-intro',
    nextLabel: 'Continue to Program Intro',
  },
} as const satisfies Record<PostAssessmentPreviewStepId, PostAssessmentPreviewStep>;
