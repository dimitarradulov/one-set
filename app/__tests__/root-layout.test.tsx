import { render } from '@testing-library/react-native';
import { readFileSync } from 'node:fs';
import type { ReactNode } from 'react';
import RootLayout from '../_layout';

const mockClerkProvider = jest.fn(({ children }: { children: ReactNode }) => <>{children}</>);

jest.mock('../../global.css', () => ({}), { virtual: true });

jest.mock('@expo-google-fonts/inter', () => ({
  Inter_400Regular: 'Inter_400Regular',
  Inter_500Medium: 'Inter_500Medium',
  Inter_600SemiBold: 'Inter_600SemiBold',
  Inter_700Bold: 'Inter_700Bold',
}));

jest.mock('@expo-google-fonts/bebas-neue', () => ({
  BebasNeue_400Regular: 'BebasNeue_400Regular',
}));

jest.mock('expo-font', () => ({
  useFonts: () => [true],
}));

jest.mock('expo-router', () => ({
  Stack: Object.assign(({ children }: { children: ReactNode }) => <>{children}</>, {
    Screen: () => null,
  }),
}));

jest.mock('expo-status-bar', () => ({
  StatusBar: () => null,
}));

jest.mock('@clerk/expo', () => ({
  ClerkProvider: (props: { children: ReactNode }) => mockClerkProvider(props),
}));

describe('root layout', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY = 'pk_test_123';
  });

  test('wraps the app with ClerkProvider and a token cache', () => {
    render(<RootLayout />);

    const props = mockClerkProvider.mock.calls[0]?.[0] as {
      publishableKey: string;
      tokenCache: {
        getToken: () => Promise<string | null>;
        saveToken: () => Promise<void>;
      };
    };

    expect(props.publishableKey).toBe('pk_test_123');
    expect(props.tokenCache).toEqual(
      expect.objectContaining({
        getToken: expect.any(Function),
        saveToken: expect.any(Function),
      })
    );
    expect(readFileSync('app/_layout.tsx', 'utf8')).toContain(
      '<Stack.Screen name="verify-email" />'
    );
  });
});
