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

jest.mock('@expo/vector-icons', () => {
  const { Text } = jest.requireActual('react-native');

  return {
    MaterialCommunityIcons: ({ name }: { name: string }) => (
      <Text accessibilityLabel={`icon-${name}`} />
    ),
  };
});

describe('onboarding route placeholders', () => {
  test('root entry redirects into onboarding welcome', () => {
    render(<RootPlaceholderScreen />);

    expect(screen.getByTestId('root-redirect').props.href).toBe('/(onboarding)');
  });

  test('welcome screen shows hero image, simplified copy, and routes begin assessment to main goal', () => {
    render(<OnboardingWelcomeScreen />);

    expect(screen.getByLabelText('Onboarding hero image')).toBeTruthy();
    expect(screen.getByLabelText('OneSet logo')).toBeTruthy();
    expect(screen.getByText('Build more muscle by training less')).toBeTruthy();
    expect(screen.getByText('Begin Assessment').props.href).toBe('/main-goal');
    expect(screen.getByText('Sign in').props.href).toBe('/auth-prompt');
  });

  test('welcome screen removes prior subtext, helper text, and benefit rows', () => {
    render(<OnboardingWelcomeScreen />);

    expect(
      screen.queryByText(
        'OneSet creates HIT-based training programs built around your experience, recovery, schedule, and equipment.'
      )
    ).toBeNull();
    expect(screen.queryByText('Takes less than 2 minutes')).toBeNull();
    expect(screen.queryByText('HIT-Only Programs')).toBeNull();
    expect(screen.queryByText('Low volume. High effort. Maximum results.')).toBeNull();
    expect(screen.queryByText('Track What Matters')).toBeNull();
    expect(screen.queryByText('Your logbook drives your progress.')).toBeNull();
    expect(screen.queryByText('Progress Over Time')).toBeNull();
    expect(screen.queryByText('Intelligent rules guide your next steps.')).toBeNull();
    expect(screen.queryByText('Recover to Grow')).toBeNull();
    expect(screen.queryByText('Training hard means recovering smart.')).toBeNull();
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
