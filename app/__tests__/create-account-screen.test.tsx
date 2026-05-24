import { fireEvent, render, screen } from '@testing-library/react-native';
import { Alert } from 'react-native';

import CreateAccountScreen from '../create-account';

const mockPush = jest.fn();
const mockReplace = jest.fn();
const mockBack = jest.fn();

jest.mock('expo-router', () => ({
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
    back: mockBack,
  }),
}));

describe('Create Account screen', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(Alert, 'alert').mockImplementation(jest.fn());
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('shows the sign-up-first UI hierarchy', () => {
    render(<CreateAccountScreen />);

    expect(screen.getByText('Create an account to save your progress')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Continue with Apple' })).toBeOnTheScreen();
    expect(screen.getByRole('image', { name: 'Apple logo' })).toBeOnTheScreen();
    expect(screen.getByText('OR')).toBeOnTheScreen();
    expect(screen.getByPlaceholderText('Email address')).toBeOnTheScreen();
    expect(screen.getByPlaceholderText('Password')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Create account' })).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Sign in' })).toBeOnTheScreen();
    expect(screen.getByText('Free to start. No payment required.')).toBeOnTheScreen();
  });

  test('keeps account actions gated behind unavailable alerts and does not navigate', () => {
    const alertSpy = jest.spyOn(Alert, 'alert');

    render(<CreateAccountScreen />);

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

    fireEvent.press(screen.getByRole('button', { name: 'Sign in' }));
    expect(alertSpy).toHaveBeenCalledWith(
      'Sign in unavailable',
      'Returning-user sign in is not connected in this build yet.'
    );

    expect(mockPush).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalled();
    expect(mockBack).not.toHaveBeenCalled();
  });
});
