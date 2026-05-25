import type { AssessmentDraftAnswers } from '@/types/assessment';

import { createPostAssessmentPreviewStore } from '../post-assessment-preview-store';

const completeDraft: AssessmentDraftAnswers = {
  mainGoal: 'build_muscle',
  trainingExperience: '1_to_3_years',
  hitExperience: 'understands_failure',
  daysAvailablePerWeek: '3',
  preferredSessionLength: '45',
  equipmentAccess: 'full_gym',
  recoveryProfile: 'average',
  lifestyleStress: 'moderate',
  limitations: ['no_limitations'],
  trainingDirection: 'classic_balanced',
  failureComfort: 'comfortable_to_failure',
};

describe('createPostAssessmentPreviewStore', () => {
  test('prepares and stores a preview-only Program Recommendation from a complete Assessment Draft', () => {
    const store = createPostAssessmentPreviewStore();

    const preparedState = store.getState().prepareRecommendation(completeDraft);

    expect(preparedState.status).toBe('ready');
    expect(store.getState().preparedState).toEqual(preparedState);
    expect(
      preparedState.status === 'ready' ? preparedState.recommendation.program.name : null
    ).toBe('Classic Symmetry Full-Body HIT');
  });

  test('keeps prepared recommendation distinct from later Assessment Draft edits until recalculated', () => {
    const store = createPostAssessmentPreviewStore();

    store.getState().prepareRecommendation(completeDraft);

    const firstPreparedState = store.getState().preparedState;
    const firstRecommendedProgramName =
      firstPreparedState?.status === 'ready'
        ? firstPreparedState.recommendation.program.name
        : null;

    expect(firstRecommendedProgramName).toBe('Classic Symmetry Full-Body HIT');

    const editedDraft: AssessmentDraftAnswers = {
      ...completeDraft,
      trainingDirection: 'minimalist_muscle',
    };
    const unchangedPreparedState = store.getState().preparedState;

    expect(
      unchangedPreparedState?.status === 'ready'
        ? unchangedPreparedState.recommendation.program.name
        : null
    ).toBe('Classic Symmetry Full-Body HIT');

    store.getState().prepareRecommendation(editedDraft);
    const recalculatedPreparedState = store.getState().preparedState;

    expect(
      recalculatedPreparedState?.status === 'ready'
        ? recalculatedPreparedState.recommendation.program.name
        : null
    ).toBe('Two-Way Split HIT');
  });
});
