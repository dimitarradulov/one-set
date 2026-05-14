import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import ExerciseHistoryDetailScreen from '../[exerciseId]';
import LogbookLayout from '../../_layout';

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

describe('logbook exercise history placeholder route', () => {
  test('layout keeps native headers hidden', () => {
    render(<LogbookLayout />);

    expect(lastStackScreenOptions).toMatchObject({
      headerShown: false,
    });
  });

  test('exercise history detail shows placeholder copy and representative links', () => {
    mockUseLocalSearchParams.mockReturnValue({ exerciseId: 'leg-press' });

    render(<ExerciseHistoryDetailScreen />);

    expect(screen.getByText('Exercise History Detail')).toBeTruthy();
    expect(
      screen.getByText(
        /Exercise context: leg-press — placeholder history detail from the logbook\./
      )
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Back to Logbook').props.href).toBe('/(tabs)/logbook');
    expect(screen.getByText('Route Test: Open Workout Session Detail').props.href).toBe(
      '/workout/session-a/summary'
    );
  });
});
