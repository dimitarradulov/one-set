import { readFileSync } from 'node:fs';

import type { AssessmentDraftAnswers } from '@/types/assessment';

import { parseProgramLibraryMarkdown } from '../program-library-parser';
import { recommendProgram } from '../program-recommendation';

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

describe('recommendProgram', () => {
  test('requires a complete Assessment Draft', () => {
    expect(() =>
      recommendProgram(
        {
          ...completeDraft,
          hitExperience: null,
        },
        library
      )
    ).toThrow(/requires hitExperience/);
  });

  test('recommends the HIT bridge for new lifters', () => {
    const recommendation = recommendProgram(
      {
        ...completeDraft,
        trainingExperience: 'new',
        hitExperience: 'none',
        failureComfort: 'reps_in_reserve',
      },
      library
    );

    expect(recommendation.program.name).toBe('Beginner Strength-to-HIT Bridge');
    expect(recommendation.startingEffort).toBe('8-9');
    expect(recommendation.internalAssessment).toMatchObject({
      trainingLevel: 'beginner',
      hitReadiness: 'new_to_hit',
    });
  });

  test('uses the Program Library to choose the home equipment program', () => {
    const recommendation = recommendProgram(
      {
        ...completeDraft,
        equipmentAccess: 'dumbbells_only',
      },
      library
    );

    expect(recommendation.program.name).toBe('Home Minimal Equipment HIT');
    expect(recommendation.whyItFits).toContain('Matches your limited-equipment training setup.');
  });

  test('does not recommend advanced programs to advanced lifters who are new to HIT', () => {
    const recommendation = recommendProgram(
      {
        ...completeDraft,
        trainingExperience: '5_plus_years',
        hitExperience: 'none',
        failureComfort: 'comfortable_to_failure',
      },
      library
    );

    expect(recommendation.internalAssessment.trainingLevel).toBe('intermediate');
    expect(recommendation.program.name).not.toBe('Athletic Power HIT');
    expect(recommendation.program.name).not.toBe('Negative-Control HIT');
    expect(recommendation.program.name).not.toBe('Rest-Pause Density HIT');
  });

  test('allows Athletic Power HIT only for advanced ready users with the right setup', () => {
    const recommendation = recommendProgram(
      {
        ...completeDraft,
        trainingExperience: '5_plus_years',
        hitExperience: 'long_time_hit',
        equipmentAccess: 'full_gym',
        recoveryProfile: 'fast',
        lifestyleStress: 'low',
        trainingDirection: 'powerhouse',
        failureComfort: 'advanced_intensity',
      },
      library
    );

    expect(recommendation.program.name).toBe('Athletic Power HIT');
    expect(recommendation.startingEffort).toBe('10 selectively');
    expect(recommendation.recoveryDemand).toBe('very_high');
  });
});
