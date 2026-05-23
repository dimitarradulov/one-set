import { PROGRAM_LIBRARY } from '@/constants/program-library';
import type { ProgramRecommendation } from '@/types/program';

import {
  buildRecommendedProgramDisplayFacts,
  formatProgramDaysPerWeek,
  formatProgramRecoveryDemand,
  formatProgramWorkoutLength,
} from '../recommended-program-display';

const classicSymmetryProgram = PROGRAM_LIBRARY.programs.find(
  (program) => program.id === 'classic-symmetry-full-body-hit'
);

if (!classicSymmetryProgram) {
  throw new Error('Expected Classic Symmetry Full-Body HIT in program library');
}

const baseRecommendation: ProgramRecommendation = {
  program: classicSymmetryProgram,
  internalAssessment: {
    trainingLevel: 'late_beginner',
    hitReadiness: 'ready_for_hit',
    recoveryCapacity: 'average',
  },
  startingEffort: '9',
  recoveryDemand: 'moderate',
  whyItFits: [
    'Matches your late beginner training profile.',
    'Fits your current comfort with high-effort HIT work.',
  ],
  afterCycle:
    'After 12 completed workouts, OneSet reviews your logbook, recovery, and stalls before changing the plan.',
};

describe('recommended program display formatter', () => {
  test('formats days/week labels from recommended schedule range', () => {
    expect(formatProgramDaysPerWeek(classicSymmetryProgram)).toBe('3 days/week');
  });

  test('formats estimated workout length from Assessment Draft preferred session length', () => {
    expect(formatProgramWorkoutLength('45')).toBe('45 minutes');
  });

  test('formats recovery demand using user-facing labels', () => {
    expect(formatProgramRecoveryDemand('very_high')).toBe('Very high');
  });

  test('builds stable screen facts from recommendation and preferred session length', () => {
    expect(buildRecommendedProgramDisplayFacts(baseRecommendation, '45')).toEqual({
      programName: 'Classic Symmetry Full-Body HIT',
      daysPerWeek: '3 days/week',
      estimatedWorkoutLength: '45 minutes',
      startingEffort: '9',
      recoveryDemand: 'Moderate',
      whyItFits: [
        'Matches your late beginner training profile.',
        'Fits your current comfort with high-effort HIT work.',
      ],
      afterCycle:
        'After 12 completed workouts, OneSet reviews your logbook, recovery, and stalls before changing the plan.',
    });
  });
});
