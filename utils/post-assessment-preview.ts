import type { Href } from 'expo-router';

import type { AssessmentDraftAnswerKey, AssessmentDraftAnswers } from '@/types/assessment';
import type { ProgramLibrary, ProgramRecommendation } from '@/types/program';
import { recommendProgram } from '@/utils/program-recommendation';

export type PostAssessmentPreviewStepId =
  | 'result-calculation'
  | 'recommended-program'
  | 'hit-principles'
  | 'first-workout-preview';

export type PostAssessmentPreviewState =
  | {
      status: 'incomplete';
      missingAnswerKeys: AssessmentDraftAnswerKey[];
    }
  | {
      status: 'ready';
      recommendation: ProgramRecommendation;
    };

export type PostAssessmentPreviewStep = {
  title: string;
  description: string;
  nextHref: Href;
  nextLabel: string;
};

const POST_ASSESSMENT_STEPS = {
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

export const getMissingAssessmentDraftAnswerKeys = (
  draft: AssessmentDraftAnswers
): AssessmentDraftAnswerKey[] =>
  (Object.keys(draft) as AssessmentDraftAnswerKey[]).filter((key) => {
    const value = draft[key];

    return Array.isArray(value) ? value.length === 0 : value === null;
  });

export const buildPostAssessmentPreviewState = (
  draft: AssessmentDraftAnswers,
  library: ProgramLibrary
): PostAssessmentPreviewState => {
  const missingAnswerKeys = getMissingAssessmentDraftAnswerKeys(draft);

  if (missingAnswerKeys.length > 0) {
    return {
      status: 'incomplete',
      missingAnswerKeys,
    };
  }

  return {
    status: 'ready',
    recommendation: recommendProgram(draft, library),
  };
};

export const getPostAssessmentPreviewStep = (
  stepId: PostAssessmentPreviewStepId
): PostAssessmentPreviewStep => POST_ASSESSMENT_STEPS[stepId];
