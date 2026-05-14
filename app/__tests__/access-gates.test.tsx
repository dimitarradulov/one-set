import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import AuthPromptPlaceholderScreen from '../auth-prompt';
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
  };
});

describe('access and legal gate placeholders', () => {
  test('program intro start links to auth prompt gate', () => {
    render(<ProgramIntroPlaceholderScreen />);

    expect(screen.getByText('Start Focused Session Preview').props.href).toBe('/auth-prompt');
  });

  test('auth prompt shows placeholder copy and links into trial paywall', () => {
    render(<AuthPromptPlaceholderScreen />);

    expect(screen.getByText('Auth Prompt Placeholder')).toBeTruthy();
    expect(
      screen.getByText(/Create an account to save your progress\. Dummy access gate content only\./)
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Continue to Trial Paywall').props.href).toBe(
      '/trial-paywall'
    );
    expect(screen.getByText('Route Test: Back to Program Preview').props.href).toBe(
      '/program-intro'
    );
  });

  test('trial paywall shows placeholder copy and links into fitness disclaimer', () => {
    render(<TrialPaywallPlaceholderScreen />);

    expect(screen.getByText('Trial Paywall Placeholder')).toBeTruthy();
    expect(
      screen.getByText(
        /14-day free trial plus subscription gate\. Dummy access gate content only\./
      )
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Continue to Fitness Disclaimer').props.href).toBe(
      '/fitness-disclaimer'
    );
    expect(screen.getByText('Route Test: Back to Auth Prompt').props.href).toBe('/auth-prompt');
  });

  test('fitness disclaimer shows placeholder copy and links into workout overview', () => {
    render(<FitnessDisclaimerPlaceholderScreen />);

    expect(screen.getByText('Fitness Disclaimer Placeholder')).toBeTruthy();
    expect(
      screen.getByText(
        /One-time legal and safety acknowledgment before real training starts\. Dummy legal gate content only\./
      )
    ).toBeTruthy();
    expect(screen.getByText('Route Test: Continue to Workout Overview').props.href).toBe(
      '/workout/session-a'
    );
    expect(screen.getByText('Route Test: Back to Trial Paywall').props.href).toBe('/trial-paywall');
  });
});
