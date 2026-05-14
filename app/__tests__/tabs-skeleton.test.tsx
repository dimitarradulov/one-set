import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import TabsLayout from '../(tabs)/_layout';
import HomeScreen from '../(tabs)/index';
import ProgramScreen from '../(tabs)/program';
import LogbookScreen from '../(tabs)/logbook';
import ProfileScreen from '../(tabs)/profile';

let lastTabsScreenOptions: { headerShown?: boolean } | undefined;

jest.mock('expo-router', () => {
  const { Text, View } = jest.requireActual('react-native');

  const Tabs = ({
    children,
    screenOptions,
  }: {
    children: ReactNode;
    screenOptions?: { headerShown?: boolean };
  }) => {
    lastTabsScreenOptions = screenOptions;
    return <View testID="tabs-layout">{children}</View>;
  };

  Tabs.Screen = ({ name, options }: { name: string; options?: { title?: string } }) => (
    <Text testID={`tab-screen-${name}`}>{options?.title ?? name}</Text>
  );

  return {
    Link: ({ href, children }: { href: string; children: ReactNode }) => (
      <Text accessibilityRole="link" href={href}>
        {children}
      </Text>
    ),
    Tabs,
  };
});

describe('mvp tab skeleton routes', () => {
  test('defines exactly four tabs with required labels and hidden headers', () => {
    render(<TabsLayout />);

    expect(screen.queryAllByTestId(/tab-screen-/)).toHaveLength(4);
    expect(screen.getByText('Home')).toBeTruthy();
    expect(screen.getByText('Program')).toBeTruthy();
    expect(screen.getByText('Logbook')).toBeTruthy();
    expect(screen.getByText('Profile')).toBeTruthy();
    expect(lastTabsScreenOptions).toMatchObject({
      headerShown: false,
    });
  });

  test('home shows mvp purpose and next-workout path links', () => {
    render(<HomeScreen />);

    expect(
      screen.getByText(
        'Dummy Home content for the MVP command center answering: What should I do next?'
      )
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Start Workout Path').props.href).toBe('/program-intro');
    expect(screen.getByText('Route Test: Open Next Workout').props.href).toBe('/workout/session-a');
  });

  test('program shows plan context and route-test links', () => {
    render(<ProgramScreen />);

    expect(
      screen.getByText('Dummy Program content for current plan context and what is coming next.')
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Workout Preview').props.href).toBe('/workout/session-a');
    expect(screen.getByText('Route Test: Exercise Detail').props.href).toBe(
      '/workout/session-a/exercise/1'
    );
  });

  test('logbook shows progress history and route-test links', () => {
    render(<LogbookScreen />);

    expect(
      screen.getByText('Dummy Logbook content for workout and exercise progress history.')
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Workout Session Detail').props.href).toBe(
      '/workout/session-a/summary'
    );
    expect(screen.getByText('Route Test: Exercise History').props.href).toBe(
      '/logbook/exercise/leg-press'
    );
  });

  test('profile shows quiet settings purpose and route-test links', () => {
    render(<ProfileScreen />);

    expect(
      screen.getByText(
        'Dummy Profile content for quiet account, subscription, assessment, preferences, and legal settings.'
      )
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Account Access').props.href).toBe('/auth-prompt');
    expect(screen.getByText('Route Test: Legal Screen').props.href).toBe('/fitness-disclaimer');
    expect(screen.getByText('Route Test: Assessment Target').props.href).toBe(
      '/recommended-program'
    );
  });
});
