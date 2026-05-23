import { readFileSync } from 'node:fs';

import type { AssessmentDraftAnswers } from '@/types/assessment';

import { parseProgramLibraryMarkdown } from '../program-library-parser';
import {
  buildPostAssessmentPreviewState,
  getMissingAssessmentDraftAnswerKeys,
  getPostAssessmentPreviewStep,
} from '../post-assessment-preview';

const library = parseProgramLibraryMarkdown(
  readFileSync('docs/hit-workout-program-library.md', 'utf8')
);

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

describe('Post-Assessment preview', () => {
  test('reports missing Assessment Draft answers before recommendation', () => {
    expect(
      getMissingAssessmentDraftAnswerKeys({
        ...completeDraft,
        hitExperience: null,
        limitations: [],
      })
    ).toEqual(['hitExperience', 'limitations']);
  });

  test('builds ready preview state from a complete Assessment Draft', () => {
    const state = buildPostAssessmentPreviewState(completeDraft, library);

    expect(state.status).toBe('ready');
    expect(state.status === 'ready' ? state.recommendation.program.name : null).toBe(
      'Classic Symmetry Full-Body HIT'
    );
  });

  test('provides route copy for post-Assessment preview steps', () => {
    expect(getPostAssessmentPreviewStep('result-calculation')).toMatchObject({
      title: 'Result Calculation',
      nextLabel: 'Next: Program Recommendation',
    });

    expect(getPostAssessmentPreviewStep('recommended-program')).toMatchObject({
      title: 'Program Recommendation',
      nextHref: '/hit-principles',
    });
  });
});
