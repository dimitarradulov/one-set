import { fireEvent, render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import type { MainGoalId } from '@/store/assessment-draft-store';

import MainGoalScreen from '../(onboarding)/main-goal';

const mockPush = jest.fn();
const mockCommitMainGoal = jest.fn();

type MockAssessmentDraftState = {
  mainGoal: MainGoalId | null;
  commitMainGoal: (mainGoal: MainGoalId) => void;
};

const mockAssessmentDraftState: MockAssessmentDraftState = {
  mainGoal: null,
  commitMainGoal: mockCommitMainGoal,
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
  }),
}));

jest.mock('@/store/assessment-draft-store', () => ({
  useAssessmentDraftStore: (selector: (state: MockAssessmentDraftState) => unknown) =>
    selector(mockAssessmentDraftState),
}));

describe('MainGoalScreen', () => {
  beforeEach(() => {
    mockPush.mockClear();
    mockCommitMainGoal.mockClear();
    mockAssessmentDraftState.mainGoal = null;
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

  test('selects an option transiently without committing or navigating', () => {
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Build muscle' }));

    expect(screen.getByRole('button', { name: 'Build muscle' })).toBeSelected();
    expect(screen.getByRole('button', { name: 'Continue' })).toBeEnabled();
    expect(mockCommitMainGoal).not.toHaveBeenCalled();
    expect(mockPush).not.toHaveBeenCalled();
  });

  test('commits on Continue and navigates explicitly to Training Experience', () => {
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Recomp my body' }));
    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitMainGoal).toHaveBeenCalledTimes(1);
    expect(mockCommitMainGoal).toHaveBeenCalledWith('recomp');
    expect(mockPush).toHaveBeenCalledTimes(1);
    expect(mockPush).toHaveBeenCalledWith('/training-experience');
  });

  test('does not commit intermediate option changes before Continue', () => {
    render(<MainGoalScreen />);

    fireEvent.press(screen.getByRole('button', { name: 'Build muscle' }));
    fireEvent.press(screen.getByRole('button', { name: 'Get stronger' }));
    fireEvent.press(screen.getByRole('button', { name: 'Return after a break' }));

    expect(mockCommitMainGoal).not.toHaveBeenCalled();

    fireEvent.press(screen.getByRole('button', { name: 'Continue' }));

    expect(mockCommitMainGoal).toHaveBeenCalledTimes(1);
    expect(mockCommitMainGoal).toHaveBeenCalledWith('return_after_break');
  });
});
