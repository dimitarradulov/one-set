import type { Href } from 'expo-router';

import type { AssessmentDraftAnswerKey } from '@/types/assessment';
import type { ProgramRecommendation } from '@/types/program';

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
