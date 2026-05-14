import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import OnboardingWelcomeScreen from '../(onboarding)/index';
import RecoveryProfileScreen from '../(onboarding)/recovery-profile';
import FirstWorkoutPreviewScreen from '../(onboarding)/first-workout-preview';
import RootPlaceholderScreen from '../index';

jest.mock('expo-router', () => {
  const { Text } = jest.requireActual('react-native');

  return {
    Link: ({ href, children }: { href: string; children: ReactNode }) => (
      <Text accessibilityRole="link" href={href}>
        {children}
      </Text>
    ),
    Redirect: ({ href }: { href: string }) => (
      <Text accessibilityRole="link" href={href} testID="root-redirect" />
    ),
  };
});

describe('onboarding route placeholders', () => {
  test('root entry redirects into onboarding welcome', () => {
    render(<RootPlaceholderScreen />);

    expect(screen.getByTestId('root-redirect').props.href).toBe('/(onboarding)');
  });

  test('welcome step shows placeholder purpose and links to main goal', () => {
    render(<OnboardingWelcomeScreen />);

    expect(screen.getByText('Welcome')).toBeTruthy();
    expect(
      screen.getByText(/Dummy welcome content introducing the coach-style onboarding assessment\./)
    ).toBeTruthy();
    expect(screen.getByText('Start Assessment').props.href).toBe('/main-goal');
  });

  test('middle step shows placeholder purpose and links to the next step', () => {
    render(<RecoveryProfileScreen />);

    expect(screen.getByText('Recovery Profile')).toBeTruthy();
    expect(
      screen.getByText(
        /Dummy assessment content for how quickly the user recovers from hard training\./
      )
    ).toBeTruthy();
    expect(screen.getByText('Next: Lifestyle Stress').props.href).toBe('/lifestyle-stress');
  });

  test('final step shows placeholder purpose and links to program intro', () => {
    render(<FirstWorkoutPreviewScreen />);

    expect(screen.getByText('First Workout Preview')).toBeTruthy();
    expect(
      screen.getByText(
        /Dummy onboarding wrap-up content previewing the first focused training session\./
      )
    ).toBeTruthy();
    expect(screen.getByText('Continue to Program Intro').props.href).toBe('/program-intro');
  });
});
