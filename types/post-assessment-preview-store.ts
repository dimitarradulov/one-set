import type { AssessmentDraftAnswers } from '@/types/assessment';
import type { PostAssessmentPreviewState } from '@/utils/post-assessment-preview';

export interface PostAssessmentPreviewStoreState {
  preparedState: PostAssessmentPreviewState | null;
  prepareRecommendation: (draft: AssessmentDraftAnswers) => PostAssessmentPreviewState;
  clearPreparedState: () => void;
}
