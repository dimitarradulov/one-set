import {
  RESULT_CALCULATION_MESSAGES,
  RESULT_CALCULATION_MESSAGE_DURATION_MS,
  RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS,
} from '@/constants/result-calculation-transition';
import type { PostAssessmentPreviewState } from '@/types/post-assessment-preview';
import type { ResultCalculationTransitionState } from '@/types/result-calculation-transition';

export const getResultCalculationMessageIndex = (elapsedMs: number): number => {
  if (elapsedMs <= 0) {
    return 0;
  }

  return Math.min(
    Math.floor(elapsedMs / RESULT_CALCULATION_MESSAGE_DURATION_MS),
    RESULT_CALCULATION_MESSAGES.length - 1
  );
};

export const getResultCalculationTransitionState = (
  elapsedMs: number,
  preparedState: PostAssessmentPreviewState | null
): ResultCalculationTransitionState => {
  const activeMessageIndex = getResultCalculationMessageIndex(elapsedMs);
  const hasMessageSequenceCompleted = elapsedMs >= RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS;
  const hasRecommendationPrepared = preparedState?.status === 'ready';

  return {
    activeMessageIndex,
    activeMessage: RESULT_CALCULATION_MESSAGES[activeMessageIndex],
    hasMessageSequenceCompleted,
    hasRecommendationPrepared,
    canAutoAdvance: hasMessageSequenceCompleted && hasRecommendationPrepared,
  };
};
