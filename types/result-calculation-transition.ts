import type { RESULT_CALCULATION_MESSAGES } from '@/constants/result-calculation-transition';

export type ResultCalculationMessage = (typeof RESULT_CALCULATION_MESSAGES)[number];

export type ResultCalculationTransitionState = {
  activeMessageIndex: number;
  activeMessage: ResultCalculationMessage;
  hasMessageSequenceCompleted: boolean;
  hasRecommendationPrepared: boolean;
  canAutoAdvance: boolean;
};
