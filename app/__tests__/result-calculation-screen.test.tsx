import { render, screen, waitFor } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import type { AssessmentDraftState } from '@/types/assessment-draft-store';

import ResultCalculationScreen from '../(onboarding)/result-calculation';

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

describe('Result Calculation screen', () => {
  beforeEach(() => {
    usePostAssessmentPreviewStore.setState({ preparedState: null });

    mockAssessmentDraftState.isHydrated = true;
    mockAssessmentDraftState.mainGoal = 'build_muscle';
    mockAssessmentDraftState.trainingExperience = '1_to_3_years';
    mockAssessmentDraftState.hitExperience = 'understands_failure';
    mockAssessmentDraftState.daysAvailablePerWeek = '3';
    mockAssessmentDraftState.preferredSessionLength = '45';
    mockAssessmentDraftState.equipmentAccess = 'full_gym';
    mockAssessmentDraftState.recoveryProfile = 'average';
    mockAssessmentDraftState.lifestyleStress = 'moderate';
    mockAssessmentDraftState.limitations = ['no_limitations'];
    mockAssessmentDraftState.trainingDirection = 'classic_balanced';
    mockAssessmentDraftState.failureComfort = 'comfortable_to_failure';
  });

  test('prepares preview recommendation state when reached with a complete Assessment Draft', async () => {
    render(<ResultCalculationScreen />);

    expect(screen.getByText('Result Calculation')).toBeOnTheScreen();

    await waitFor(() => {
      expect(usePostAssessmentPreviewStore.getState().preparedState?.status).toBe('ready');
    });

    const preparedState = usePostAssessmentPreviewStore.getState().preparedState;

    expect(
      preparedState?.status === 'ready' ? preparedState.recommendation.program.name : null
    ).toBe('Classic Symmetry Full-Body HIT');
  });

  test('stores incomplete preview state when required Assessment Draft answers are missing', async () => {
    mockAssessmentDraftState.hitExperience = null;
    mockAssessmentDraftState.limitations = [];

    render(<ResultCalculationScreen />);

    await waitFor(() => {
      expect(usePostAssessmentPreviewStore.getState().preparedState?.status).toBe('incomplete');
    });

    const preparedState = usePostAssessmentPreviewStore.getState().preparedState;

    expect(preparedState?.status === 'incomplete' ? preparedState.missingAnswerKeys : []).toEqual([
      'hitExperience',
      'limitations',
    ]);
  });
});
