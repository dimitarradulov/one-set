import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import ActiveExerciseScreen from '../exercise/[exerciseId]';
import WorkoutOverviewScreen from '../index';
import RestTimerScreen from '../rest/[exerciseId]';
import WorkoutSummaryScreen from '../summary';
import WorkoutSessionLayout from '../_layout';

const mockUseLocalSearchParams = jest.fn();
let lastStackScreenOptions: { headerShown?: boolean } | undefined;

jest.mock('expo-router', () => {
  const { Text, View } = jest.requireActual('react-native');

  const Stack = ({ screenOptions }: { screenOptions?: { headerShown?: boolean } }) => {
    lastStackScreenOptions = screenOptions;
    return <View testID="stack-layout" />;
  };

  return {
    Link: ({ href, children }: { href: string; children: ReactNode }) => (
      <Text accessibilityRole="link" href={href}>
        {children}
      </Text>
    ),
    Stack,
    useLocalSearchParams: () => mockUseLocalSearchParams(),
  };
});

describe('workout session placeholder flow routes', () => {
  test('shared workout detail layout keeps native headers hidden', () => {
    render(<WorkoutSessionLayout />);

    expect(lastStackScreenOptions).toMatchObject({
      headerShown: false,
    });
  });

  test('overview shows placeholder copy and links to first active exercise', () => {
    mockUseLocalSearchParams.mockReturnValue({ sessionId: 'session-a' });

    render(<WorkoutOverviewScreen />);

    expect(screen.getByText('Workout Overview')).toBeTruthy();
    expect(
      screen.getByText(/Session context: session-a — placeholder pre-workout overview content\./)
    ).toBeTruthy();
    expect(screen.getByText('Start Exercise 1').props.href).toBe('/workout/session-a/exercise/1');
    expect(screen.getByText('Route Test: Back to Program').props.href).toBe('/(tabs)/program');
  });

  test('active exercise shows placeholder copy and links to rest timer', () => {
    mockUseLocalSearchParams.mockReturnValue({ sessionId: 'session-a', exerciseId: '1' });

    render(<ActiveExerciseScreen />);

    expect(screen.getByText('Active Exercise')).toBeTruthy();
    expect(
      screen.getByText(
        /Session: session-a • Exercise: 1 — placeholder one-exercise-at-a-time logging\./
      )
    ).toBeTruthy();
    expect(screen.getByText('Complete Set and Start Rest').props.href).toBe(
      '/workout/session-a/rest/1'
    );
    expect(screen.getByText('Route Test: Back to Workout Overview').props.href).toBe(
      '/workout/session-a'
    );
  });

  test('rest timer shows placeholder copy and links to next exercise or summary', () => {
    mockUseLocalSearchParams.mockReturnValue({ sessionId: 'session-a', exerciseId: '1' });

    render(<RestTimerScreen />);

    expect(screen.getByText('Rest Timer')).toBeTruthy();
    expect(
      screen.getByText(/Session: session-a • Rest after exercise: 1 — placeholder rest step\./)
    ).toBeTruthy();
    expect(screen.getByText('Continue to Exercise 2').props.href).toBe(
      '/workout/session-a/exercise/2'
    );
    expect(screen.getByText('Finish Workout').props.href).toBe('/workout/session-a/summary');
  });

  test('summary shows placeholder copy and links back to home and logbook', () => {
    mockUseLocalSearchParams.mockReturnValue({ sessionId: 'session-a' });

    render(<WorkoutSummaryScreen />);

    expect(screen.getByText('Workout Summary')).toBeTruthy();
    expect(
      screen.getByText(/Session context: session-a — placeholder post-workout summary\./)
    ).toBeTruthy();
    expect(screen.getByText('Back to Home').props.href).toBe('/(tabs)');
    expect(screen.getByText('Back to Logbook').props.href).toBe('/(tabs)/logbook');
  });
});
