import { fireEvent, render, screen } from '@testing-library/react-native';
import { Alert } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import CreateAccountScreen from '../create-account';

const mockPush = jest.fn();
const mockReplace = jest.fn();
const mockBack = jest.fn();
const mockCanGoBack = jest.fn(() => false);

jest.mock('expo-router', () => ({
  useRouter: () => ({
    canGoBack: mockCanGoBack,
    push: mockPush,
    replace: mockReplace,
    back: mockBack,
  }),
}));

const renderCreateAccountScreen = () =>
  render(
    <SafeAreaProvider
      initialMetrics={{
        frame: { x: 0, y: 0, width: 390, height: 844 },
        insets: { top: 47, right: 0, bottom: 34, left: 0 },
      }}>
      <CreateAccountScreen />
    </SafeAreaProvider>
  );

describe('Create Account screen', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(Alert, 'alert').mockImplementation(jest.fn());
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('shows the sign-up-first UI hierarchy', () => {
    renderCreateAccountScreen();

    expect(screen.getByRole('button', { name: 'Close account creation prompt' })).toBeOnTheScreen();
    expect(screen.getByText('X')).toBeOnTheScreen();
    expect(screen.queryByText('Close')).not.toBeOnTheScreen();
    expect(screen.getByText('Create an account to save your progress')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Continue with Apple' })).toBeOnTheScreen();
    expect(screen.getByRole('image', { name: 'Apple logo' })).toBeOnTheScreen();
    expect(screen.getByText('OR')).toBeOnTheScreen();
    expect(screen.getByPlaceholderText('Email address')).toBeOnTheScreen();
    expect(screen.getByPlaceholderText('Password')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Create account' })).toBeOnTheScreen();
    expect(
      screen.getByRole('button', { name: 'Already have an account? Sign in.' })
    ).toBeOnTheScreen();
    expect(screen.getByText('Free to start. No payment required.')).toBeOnTheScreen();
  });

  test('keeps account actions gated behind unavailable alerts and does not navigate', () => {
    const alertSpy = jest.spyOn(Alert, 'alert');

    renderCreateAccountScreen();

    fireEvent.press(screen.getByRole('button', { name: 'Continue with Apple' }));
    expect(alertSpy).toHaveBeenCalledWith(
      'Apple sign in unavailable',
      'Sign in with Apple is not configured in this build yet.'
    );

    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));
    expect(alertSpy).toHaveBeenCalledWith(
      'Account creation unavailable',
      'Email account creation is not connected in this build yet.'
    );

    fireEvent.press(screen.getByRole('button', { name: 'Already have an account? Sign in.' }));
    expect(alertSpy).toHaveBeenCalledWith(
      'Sign in unavailable',
      'Returning-user sign in is not connected in this build yet.'
    );

    expect(mockPush).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalled();
    expect(mockBack).not.toHaveBeenCalled();
  });

  test('dismisses to Program Recommendation when there is no navigation history', () => {
    mockCanGoBack.mockReturnValue(false);
    renderCreateAccountScreen();

    fireEvent.press(screen.getByRole('button', { name: 'Close account creation prompt' }));

    expect(mockCanGoBack).toHaveBeenCalledTimes(1);
    expect(mockBack).not.toHaveBeenCalled();
    expect(mockReplace).toHaveBeenCalledWith('/recommended-program');
    expect(mockPush).not.toHaveBeenCalled();
  });
});
