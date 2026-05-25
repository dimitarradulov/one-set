import {
  RESULT_CALCULATION_MESSAGE_DURATION_MS,
  RESULT_CALCULATION_MESSAGES,
  RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS,
} from '@/constants/result-calculation-transition';

import {
  getResultCalculationMessageIndex,
  getResultCalculationTransitionState,
} from '../result-calculation-transition';

describe('Result Calculation transition', () => {
  test('uses the fixed four-step sequence from the spec', () => {
    expect(RESULT_CALCULATION_MESSAGES).toEqual([
      'Analyzing your training level…',
      'Matching your recovery profile…',
      'Selecting your HIT frequency…',
      'Building your starter program…',
    ]);
  });

  test('advances the message index by fixed duration and caps at the final step', () => {
    expect(getResultCalculationMessageIndex(0)).toBe(0);
    expect(getResultCalculationMessageIndex(RESULT_CALCULATION_MESSAGE_DURATION_MS - 1)).toBe(0);
    expect(getResultCalculationMessageIndex(RESULT_CALCULATION_MESSAGE_DURATION_MS)).toBe(1);
    expect(getResultCalculationMessageIndex(RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS)).toBe(3);
    expect(
      getResultCalculationMessageIndex(RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS + 10_000)
    ).toBe(3);
  });

  test('allows auto-advance only when minimum duration and ready recommendation are both complete', () => {
    const beforeMinimumDuration = getResultCalculationTransitionState(
      RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS - 1,
      {
        status: 'ready',
        recommendation: {} as never,
      }
    );

    expect(beforeMinimumDuration.hasMessageSequenceCompleted).toBe(false);
    expect(beforeMinimumDuration.hasRecommendationPrepared).toBe(true);
    expect(beforeMinimumDuration.canAutoAdvance).toBe(false);

    const afterMinimumDuration = getResultCalculationTransitionState(
      RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS,
      {
        status: 'ready',
        recommendation: {} as never,
      }
    );

    expect(afterMinimumDuration.hasMessageSequenceCompleted).toBe(true);
    expect(afterMinimumDuration.hasRecommendationPrepared).toBe(true);
    expect(afterMinimumDuration.canAutoAdvance).toBe(true);

    const incompletePreparation = getResultCalculationTransitionState(
      RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS,
      {
        status: 'incomplete',
        missingAnswerKeys: ['mainGoal'],
      }
    );

    expect(incompletePreparation.hasMessageSequenceCompleted).toBe(true);
    expect(incompletePreparation.hasRecommendationPrepared).toBe(false);
    expect(incompletePreparation.canAutoAdvance).toBe(false);
  });
});
