import { act, render, screen } from '@testing-library/react-native';
import { BackHandler } from 'react-native';

import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import type { AssessmentDraftState } from '@/types/assessment-draft-store';
import {
  RESULT_CALCULATION_MESSAGE_DURATION_MS,
  RESULT_CALCULATION_MESSAGES,
  RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS,
} from '@/utils/result-calculation-transition';

import ResultCalculationScreen from '../(onboarding)/result-calculation';

const mockReplace = jest.fn();

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
    useRouter: () => ({
      replace: mockReplace,
    }),
    Stack: {
      Screen: ({ options }: { options: Record<string, unknown> }) => (
        <Text testID="result-calculation-stack-options">{JSON.stringify(options)}</Text>
      ),
    },
  };
});

jest.mock('@/store/assessment-draft-store', () => ({
  useAssessmentDraftStore: (selector: (state: AssessmentDraftState) => unknown) =>
    selector(mockAssessmentDraftState),
}));

describe('Result Calculation screen', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.clearAllMocks();

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

  afterEach(() => {
    jest.runOnlyPendingTimers();
    jest.useRealTimers();
  });

  test('runs fixed staged messages, locks navigation controls, and auto-advances after the minimum duration', () => {
    const backHandlerSpy = jest
      .spyOn(BackHandler, 'addEventListener')
      .mockReturnValue({ remove: jest.fn() } as never);

    render(<ResultCalculationScreen />);

    expect(screen.getByText('Result Calculation')).toBeOnTheScreen();
    expect(screen.getByText(RESULT_CALCULATION_MESSAGES[0])).toBeOnTheScreen();
    expect(screen.queryByRole('link')).toBeNull();
    expect(screen.queryByRole('button', { name: 'Back' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'Continue' })).toBeNull();
    expect(screen.getByTestId('result-calculation-stack-options').props.children).toContain(
      '"gestureEnabled":false'
    );
    expect(backHandlerSpy).toHaveBeenCalledWith('hardwareBackPress', expect.any(Function));
    expect(usePostAssessmentPreviewStore.getState().preparedState?.status).toBe('ready');
    expect(mockReplace).not.toHaveBeenCalled();

    act(() => {
      jest.advanceTimersByTime(RESULT_CALCULATION_MESSAGE_DURATION_MS);
    });
    expect(screen.getByText(RESULT_CALCULATION_MESSAGES[1])).toBeOnTheScreen();
    expect(mockReplace).not.toHaveBeenCalled();

    act(() => {
      jest.advanceTimersByTime(RESULT_CALCULATION_MESSAGE_DURATION_MS);
    });
    expect(screen.getByText(RESULT_CALCULATION_MESSAGES[2])).toBeOnTheScreen();
    expect(mockReplace).not.toHaveBeenCalled();

    act(() => {
      jest.advanceTimersByTime(RESULT_CALCULATION_MESSAGE_DURATION_MS);
    });
    expect(screen.getByText(RESULT_CALCULATION_MESSAGES[3])).toBeOnTheScreen();
    expect(mockReplace).not.toHaveBeenCalled();

    act(() => {
      jest.advanceTimersByTime(RESULT_CALCULATION_MESSAGE_DURATION_MS);
    });

    expect(mockReplace).toHaveBeenCalledTimes(1);
    expect(mockReplace).toHaveBeenCalledWith('/recommended-program');

    backHandlerSpy.mockRestore();
  });

  test('does not auto-advance when recommendation preparation is incomplete', () => {
    mockAssessmentDraftState.hitExperience = null;
    mockAssessmentDraftState.limitations = [];

    render(<ResultCalculationScreen />);

    act(() => {
      jest.advanceTimersByTime(RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS + 100);
    });

    expect(usePostAssessmentPreviewStore.getState().preparedState?.status).toBe('incomplete');
    expect(mockReplace).not.toHaveBeenCalled();
  });
});
