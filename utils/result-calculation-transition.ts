import type { PostAssessmentPreviewState } from '@/utils/post-assessment-preview';

export const RESULT_CALCULATION_MESSAGES = [
  'Analyzing your training level…',
  'Matching your recovery profile…',
  'Selecting your HIT frequency…',
  'Building your starter program…',
] as const;

export const RESULT_CALCULATION_MESSAGE_DURATION_MS = 900;

export const RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS =
  RESULT_CALCULATION_MESSAGES.length * RESULT_CALCULATION_MESSAGE_DURATION_MS;

export type ResultCalculationMessage = (typeof RESULT_CALCULATION_MESSAGES)[number];

export type ResultCalculationTransitionState = {
  activeMessageIndex: number;
  activeMessage: ResultCalculationMessage;
  hasMessageSequenceCompleted: boolean;
  hasRecommendationPrepared: boolean;
  canAutoAdvance: boolean;
};

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
  const hasMessageSequenceCompleted =
    elapsedMs >= RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS;
  const hasRecommendationPrepared = preparedState?.status === 'ready';

  return {
    activeMessageIndex,
    activeMessage: RESULT_CALCULATION_MESSAGES[activeMessageIndex],
    hasMessageSequenceCompleted,
    hasRecommendationPrepared,
    canAutoAdvance: hasMessageSequenceCompleted && hasRecommendationPrepared,
  };
};
