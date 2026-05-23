import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import { PROGRAM_LIBRARY } from '@/constants/program-library';
import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import type { AssessmentDraftState } from '@/types/assessment-draft-store';
import type { ProgramRecommendation } from '@/types/program';

import RecommendedProgramScreen from '../(onboarding)/recommended-program';

const mockAssessmentDraftState: AssessmentDraftState = {
  isHydrated: true,
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
  setHydrated: jest.fn(),
  commitMainGoal: jest.fn(),
  commitLimitations: jest.fn(),
  commitFailureComfort: jest.fn(),
  commitAnswer: jest.fn(),
};

const classicSymmetryProgram = PROGRAM_LIBRARY.programs.find(
  (program) => program.id === 'classic-symmetry-full-body-hit'
);

if (!classicSymmetryProgram) {
  throw new Error('Expected Classic Symmetry Full-Body HIT in program library');
}

const mockRecommendation: ProgramRecommendation = {
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
    'Fits a 3-3 day training week.',
  ],
  afterCycle:
    'After 12 completed workouts, OneSet reviews your logbook, recovery, and stalls before changing the plan.',
};

jest.mock('expo-router', () => {
  const { Text } = jest.requireActual('react-native');

  return {
    Link: ({ href, children }: { href: string; children: ReactNode }) => (
      <Text accessibilityRole="link" href={href}>
        {children}
      </Text>
    ),
  };
});

jest.mock('@/store/assessment-draft-store', () => ({
  useAssessmentDraftStore: (selector: (state: AssessmentDraftState) => unknown) =>
    selector(mockAssessmentDraftState),
}));

describe('Recommended Program screen', () => {
  beforeEach(() => {
    usePostAssessmentPreviewStore.setState({
      preparedState: {
        status: 'ready',
        recommendation: mockRecommendation,
      },
    });
  });

  test('shows ready-state recommendation facts and routes Continue to auth prompt', () => {
    render(<RecommendedProgramScreen />);

    expect(screen.getByText('Program Recommendation')).toBeOnTheScreen();
    expect(screen.getByText('Classic Symmetry Full-Body HIT')).toBeOnTheScreen();
    expect(screen.getByText('3 days/week')).toBeOnTheScreen();
    expect(screen.getByText('45 minutes')).toBeOnTheScreen();
    expect(screen.getByText('9')).toBeOnTheScreen();
    expect(screen.getByText('Moderate')).toBeOnTheScreen();
    expect(screen.getByText(/Matches your late beginner training profile\./)).toBeOnTheScreen();
    expect(
      screen.getByText(
        'After 12 completed workouts, OneSet reviews your logbook, recovery, and stalls before changing the plan.'
      )
    ).toBeOnTheScreen();
    expect(screen.getByText('Continue').props.href).toBe('/auth-prompt');
    expect(screen.getByText('Free to start. No payment required.')).toBeOnTheScreen();
  });

  test('shows missing-state recovery and routes back to Result Calculation', () => {
    usePostAssessmentPreviewStore.setState({ preparedState: null });

    render(<RecommendedProgramScreen />);

    expect(
      screen.getByText(/OneSet needs to recalculate your starter program/i)
    ).toBeOnTheScreen();
    expect(screen.getByText('Return to Result Calculation').props.href).toBe('/result-calculation');
  });
});
