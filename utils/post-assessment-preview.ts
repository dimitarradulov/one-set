import { POST_ASSESSMENT_STEPS } from '@/constants/post-assessment-preview';
import type { AssessmentDraftAnswerKey, AssessmentDraftAnswers } from '@/types/assessment';
import type { ProgramLibrary } from '@/types/program';
import type {
  PostAssessmentPreviewState,
  PostAssessmentPreviewStep,
  PostAssessmentPreviewStepId,
} from '@/types/post-assessment-preview';
import { recommendProgram } from '@/utils/program-recommendation';

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
