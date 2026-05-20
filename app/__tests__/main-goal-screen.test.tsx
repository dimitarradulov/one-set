import { render, screen } from '@testing-library/react-native';

import FailureComfortScreen from '../(onboarding)/failure-comfort';
import LimitationsScreen from '../(onboarding)/limitations';
import MainGoalScreen from '../(onboarding)/main-goal';
import TrainingExperienceScreen from '../(onboarding)/training-experience';

jest.mock('@/components/AssessmentIntakeScreen', () => {
  const { Text } = jest.requireActual('react-native');

  return ({ questionId }: { questionId: string }) => <Text>{`question:${questionId}`}</Text>;
});

describe('Assessment Intake route wrappers', () => {
  test('main goal route delegates to the shared intake screen', () => {
    render(<MainGoalScreen />);

    expect(screen.getByText('question:main-goal')).toBeOnTheScreen();
  });

  test('training experience route delegates to the shared intake screen', () => {
    render(<TrainingExperienceScreen />);

    expect(screen.getByText('question:training-experience')).toBeOnTheScreen();
  });

  test('limitations route delegates to the shared intake screen', () => {
    render(<LimitationsScreen />);

    expect(screen.getByText('question:limitations')).toBeOnTheScreen();
  });

  test('final intake route delegates to the shared intake screen', () => {
    render(<FailureComfortScreen />);

    expect(screen.getByText('question:failure-comfort')).toBeOnTheScreen();
  });
});
