import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import CreateAccountScreen from '../create-account';
import TrialPaywallPlaceholderScreen from '../trial-paywall';
import FitnessDisclaimerPlaceholderScreen from '../fitness-disclaimer';
import ProgramIntroPlaceholderScreen from '../program-intro';

jest.mock('expo-router', () => {
  const { Text } = jest.requireActual('react-native');

  return {
    Link: ({ href, children }: { href: string; children: ReactNode }) => (
      <Text accessibilityRole="link" href={href}>
        {children}
      </Text>
    ),
    useRouter: () => ({
      canGoBack: () => false,
      back: jest.fn(),
      replace: jest.fn(),
      push: jest.fn(),
    }),
  };
});

describe('access and legal gate placeholders', () => {
  test('program intro start links to create-account gate', () => {
    render(<ProgramIntroPlaceholderScreen />);

    expect(screen.getByText('Start Focused Session Preview').props.href).toBe('/create-account');
  });

  test('create-account shows account creation prompt copy', () => {
    render(
      <SafeAreaProvider
        initialMetrics={{
          frame: { x: 0, y: 0, width: 390, height: 844 },
          insets: { top: 47, right: 0, bottom: 34, left: 0 },
        }}>
        <CreateAccountScreen />
      </SafeAreaProvider>
    );

    expect(screen.getByText('Create an account to save your progress')).toBeTruthy();
    expect(screen.queryByText('Continue to Trial Paywall')).toBeNull();
  });

  test('trial paywall shows placeholder copy and links into fitness disclaimer', () => {
    render(<TrialPaywallPlaceholderScreen />);

    expect(screen.getByText('Trial Paywall')).toBeTruthy();
    expect(screen.getByText(/14-day free trial plus subscription gate\./)).toBeTruthy();
    expect(screen.getByText('Continue to Fitness Disclaimer').props.href).toBe(
      '/fitness-disclaimer'
    );
    expect(screen.getByText('Back to Create Account').props.href).toBe('/create-account');
  });

  test('fitness disclaimer shows placeholder copy and links into workout overview', () => {
    render(<FitnessDisclaimerPlaceholderScreen />);

    expect(screen.getByText('Fitness Disclaimer')).toBeTruthy();
    expect(
      screen.getByText(/One-time legal and safety acknowledgment before real training starts\./)
    ).toBeTruthy();
    expect(screen.getByText('Continue to Workout Overview').props.href).toBe('/workout/session-a');
    expect(screen.getByText('Back to Trial Paywall').props.href).toBe('/trial-paywall');
  });
});
