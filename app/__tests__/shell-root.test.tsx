import { render, screen } from '@testing-library/react-native';
import type { ReactNode } from 'react';

import OnboardingPlaceholderScreen from '../(onboarding)/index';
import RootPlaceholderScreen from '../index';

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

describe('route shell placeholders', () => {
  test('root entry route is nonblank and links to onboarding placeholder', () => {
    render(<RootPlaceholderScreen />);

    expect(screen.getByText('OneSet Route Skeleton')).toBeTruthy();
    expect(screen.getByText('Begin Onboarding Placeholder').props.href).toBe('/(onboarding)');
  });

  test('onboarding placeholder links to program preview placeholder', () => {
    render(<OnboardingPlaceholderScreen />);

    expect(screen.getByText('Onboarding Placeholder')).toBeTruthy();
    expect(screen.getByText('Continue to Program Preview').props.href).toBe('/program-intro');
  });
});
