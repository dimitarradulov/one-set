import { fireEvent, render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import type { AssessmentDraftState } from '@/types/assessment-draft-store';

import LimitationsScreen from '../(onboarding)/limitations';
import MainGoalScreen from '../(onboarding)/main-goal';
import TrainingExperienceScreen from '../(onboarding)/training-experience';

const mockPush = jest.fn();
const mockReplace = jest.fn();
const mockCommitAnswer = jest.fn();

const mockAssessmentDraftState: AssessmentDraftState = {
  isHydrated: true,
  mainGoal: null,
  trainingExperience: null,
  hitExperience: null,
  daysAvailablePerWeek: null,
  preferredSessionLength: null,
  equipmentAccess: null,
  recoveryProfile: null,
  lifestyleStress: null,
  limitations: [],
  trainingDirection: null,
  failureComfort: null,
  setHydrated: jest.fn(),
  commitMainGoal: jest.fn(),
  commitLimitations: jest.fn(),
  commitFailureComfort: jest.fn(),
  commitAnswer: mockCommitAnswer,
};

jest.mock('expo-router', () => ({
  Link: ({ href, children }: { href: string; children: ReactNode }) => {
    const { Text } = jest.requireActual('react-native');

    return (
      <Text accessibilityRole="link" href={href}>
        {children}
      </Text>
    );
  },
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
  }),
}));

jest.mock('@/store/assessment-draft-store', () => ({
  useAssessmentDraftStore: (selector: (state: AssessmentDraftState) => unknown) =>
    selector(mockAssessmentDraftState),
}));

describe('MainGoalScreen', () => {
  beforeEach(() => {
    mockPush.mockClear();
    mockReplace.mockClear();
    mockCommitAnswer.mockClear();
    mockAssessmentDraftState.isHydrated = true;
    mockAssessmentDraftState.mainGoal = null;
    mockAssessmentDraftState.trainingExperience = null;
    mockAssessmentDraftState.limitations = [];
  });

  test('renders the question content and keeps Continue disabled before selection', () => {
    render(<MainGoalScreen />);

    expect(screen.getByText('Question 1 of 11')).toBeTruthy();
    expect(screen.getByText('What is your main goal right now?')).toBeTruthy();
    expect(screen.getByText('Pick the result you care about most right now.')).toBeTruthy();

    expect(screen.getByText('Build muscle')).toBeTruthy();
    expect(screen.getByText('Get stronger')).toBeTruthy();
    expect(screen.getByText('Recomp my body')).toBeTruthy();
    expect(screen.getByText('Maintain muscle with less time')).toBeTruthy();
    expect(screen.getByText('Return after a break')).toBeTruthy();

    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled();
  });

  test('keeps the normal screen shell visible but disables controls while hydrating', () => {
    mockAssessmentDraftState.isHydrated = false;

    render(<MainGoalScreen />);

    expect(screen.getByText('Question 1 of 11')).toBeTruthy();
    expect(screen.getByText('What is your main goal right now?')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled();
  });

  test('restores a committed Main Goal after hydration completes', () => {
    mockAssessmentDraftState.isHydrated = false;
    const { rerender } = render(<MainGoalScreen />);

    mockAssessmentDraftState.mainGoal = 'get_stronger';
    mockAssessmentDraftState.isHydrated = true;
    rerender(<MainGoalScreen />);

    expect(screen.getByRole('button', { name: 'Get stronger' })).toBeSelected();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeEnabled();
  });

  test('selects an option transiently without committing or navigating', () => {
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Build muscle' }));

    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeSelected();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeEnabled();
    expect(mockCommitAnswer).not.toHaveBeenCalled();
    expect(mockPush).not.toHaveBeenCalled();
  });

  test('commits on Continue and navigates explicitly to Training Experience', () => {
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Recomp my body' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledTimes(1);
    expect(mockCommitAnswer).toHaveBeenCalledWith('mainGoal', 'recomp');
    expect(mockPush).toHaveBeenCalledTimes(1);
    expect(mockPush).toHaveBeenCalledWith('/training-experience');
  });

  test('replaces a previously committed Main Goal only after Continue', () => {
    mockAssessmentDraftState.mainGoal = 'build_muscle';
    render(<MainGoalScreen />);

    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeSelected();

    fireEvent.press(screen.getByRole('button', { name: 'Get stronger' }));

    expect(mockCommitAnswer).not.toHaveBeenCalled();

    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledTimes(1);
    expect(mockCommitAnswer).toHaveBeenCalledWith('mainGoal', 'get_stronger');
    expect(mockPush).toHaveBeenCalledWith('/training-experience');
  });

  test('uses explicit Back navigation without committing transient changes', () => {
    mockAssessmentDraftState.mainGoal = 'build_muscle';
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Return after a break' }));
    fireEvent.press(screen.getByRole('button', { name: 'Back' }));

    expect(mockCommitAnswer).not.toHaveBeenCalled();
    expect(mockReplace).toHaveBeenCalledTimes(1);
    expect(mockReplace).toHaveBeenCalledWith('/(onboarding)');
    expect(mockPush).not.toHaveBeenCalled();
  });

  test('does not commit intermediate option changes before Continue', () => {
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Build muscle' }));
    fireEvent.press(screen.getByRole('button', { name: 'Get stronger' }));
    fireEvent.press(screen.getByRole('button', { name: 'Return after a break' }));

    expect(mockCommitAnswer).not.toHaveBeenCalled();

    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledTimes(1);
    expect(mockCommitAnswer).toHaveBeenCalledWith('mainGoal', 'return_after_break');
  });

  test('uses the shared Assessment Intake adapter for Training Experience', () => {
    render(<TrainingExperienceScreen />);

    expect(screen.getByText('Question 2 of 11')).toBeTruthy();
    expect(screen.getByText('How long have you been lifting consistently?')).toBeTruthy();

    fireEvent.press(screen.getByRole('button', { name: '1-3 years' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledWith('trainingExperience', '1_to_3_years');
    expect(mockPush).toHaveBeenCalledWith('/hit-experience');
  });

  test('uses the shared Assessment Intake adapter for multi-select Limitations', () => {
    render(<LimitationsScreen />);

    expect(screen.getByText('Question 9 of 11')).toBeTruthy();
    expect(screen.getByText('Any areas we should be careful with?')).toBeTruthy();

    fireEvent.press(screen.getByRole('checkbox', { name: 'Shoulders' }));
    fireEvent.press(screen.getByRole('checkbox', { name: 'Wrists' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledWith('limitations', ['shoulders', 'wrists']);
    expect(mockPush).toHaveBeenCalledWith('/training-direction');
  });

  test('keeps No limitations mutually exclusive with other limitations', () => {
    render(<LimitationsScreen />);

    fireEvent.press(screen.getByRole('checkbox', { name: 'Shoulders' }));
    fireEvent.press(screen.getByRole('checkbox', { name: 'No limitations' }));

    expect(screen.getByRole('checkbox', { name: 'Shoulders' })).not.toBeChecked();
    expect(screen.getByRole('checkbox', { name: 'No limitations' })).toBeChecked();

    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledWith('limitations', ['no_limitations']);
  });
});
