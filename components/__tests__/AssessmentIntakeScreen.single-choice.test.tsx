import { fireEvent, render, screen } from '@testing-library/react-native';

import AssessmentIntakeScreen from '@/components/AssessmentIntakeScreen';
import type { AssessmentDraftState } from '@/types/assessment-draft-store';

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
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
  }),
}));

jest.mock('@/store/assessment-draft-store', () => ({
  useAssessmentDraftStore: (selector: (state: AssessmentDraftState) => unknown) =>
    selector(mockAssessmentDraftState),
}));

describe('AssessmentIntakeScreen single-choice path', () => {
  beforeEach(() => {
    mockPush.mockClear();
    mockReplace.mockClear();
    mockCommitAnswer.mockClear();

    mockAssessmentDraftState.isHydrated = true;
    mockAssessmentDraftState.mainGoal = null;
  });

  test('renders question content, progress, and total step count for a single-choice question', () => {
    render(<AssessmentIntakeScreen questionId="main-goal" />);

    expect(screen.getByText('Question 1 of 11')).toBeOnTheScreen();
    expect(screen.getByText('What is your main goal right now?')).toBeOnTheScreen();
    expect(screen.getByText('Pick the result you care about most right now.')).toBeOnTheScreen();
    expect(screen.getByText('Build muscle')).toBeOnTheScreen();
    expect(screen.getByText('Get stronger')).toBeOnTheScreen();
  });

  test('keeps Continue disabled until an answer is selected', () => {
    render(<AssessmentIntakeScreen questionId="main-goal" />);

    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled();

    fireEvent.press(screen.getByRole('button', { name: 'Build muscle' }));

    expect(screen.getByRole('button', { name: 'Continue' })).toBeEnabled();
  });

  test('disables controls while assessment draft state is not hydrated', () => {
    mockAssessmentDraftState.isHydrated = false;

    render(<AssessmentIntakeScreen questionId="main-goal" />);

    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled();
  });

  test('restores a previously committed answer after hydration', () => {
    mockAssessmentDraftState.isHydrated = false;

    const { rerender } = render(<AssessmentIntakeScreen questionId="main-goal" />);

    mockAssessmentDraftState.mainGoal = 'get_stronger';
    mockAssessmentDraftState.isHydrated = true;
    rerender(<AssessmentIntakeScreen questionId="main-goal" />);

    expect(screen.getByRole('button', { name: 'Get stronger' })).toBeSelected();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeEnabled();
  });

  test('updates visible selected state without committing immediately', () => {
    render(<AssessmentIntakeScreen questionId="main-goal" />);

    fireEvent.press(screen.getByRole('button', { name: 'Recomp my body' }));

    expect(screen.getByRole('button', { name: 'Recomp my body' })).toBeSelected();
    expect(mockCommitAnswer).not.toHaveBeenCalled();
    expect(mockPush).not.toHaveBeenCalled();
  });

  test('commits selected answer on Continue and navigates to configured next route', () => {
    render(<AssessmentIntakeScreen questionId="main-goal" />);

    fireEvent.press(screen.getByRole('button', { name: 'Return after a break' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitAnswer).toHaveBeenCalledTimes(1);
    expect(mockCommitAnswer).toHaveBeenCalledWith('mainGoal', 'return_after_break');
    expect(mockPush).toHaveBeenCalledTimes(1);
    expect(mockPush).toHaveBeenCalledWith('/training-experience');
  });

  test('routes Back to configured previous route without committing transient changes', () => {
    mockAssessmentDraftState.mainGoal = 'build_muscle';

    render(<AssessmentIntakeScreen questionId="main-goal" />);

    fireEvent.press(screen.getByRole('button', { name: 'Get stronger' }));
    fireEvent.press(screen.getByRole('button', { name: 'Back' }));

    expect(mockCommitAnswer).not.toHaveBeenCalled();
    expect(mockPush).not.toHaveBeenCalled();
    expect(mockReplace).toHaveBeenCalledTimes(1);
    expect(mockReplace).toHaveBeenCalledWith('/(onboarding)');
  });
});
