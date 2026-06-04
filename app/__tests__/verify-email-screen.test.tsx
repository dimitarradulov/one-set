import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import VerifyEmailScreen from '../verify-email';
import {
  clearPendingAuthFlow,
  getPendingAuthFlow,
  setPendingAuthFlow,
} from '@/utils/pending-auth-flow';

const mockReplace = jest.fn();
const mockAttemptEmailAddressVerification = jest.fn();
const mockPrepareEmailVerification = jest.fn();
const mockSetActive = jest.fn();
const mockGetToken = jest.fn();
const mockLinkAppUser = jest.fn();
const mockUseSignUp = jest.fn();
const mockUseClerk = jest.fn();
const mockUseAuth = jest.fn();
const mockIsClerkAPIResponseError = jest.fn(() => false);

jest.mock('expo-router', () => ({
  useRouter: () => ({
    canGoBack: jest.fn(() => false),
    back: jest.fn(),
    push: jest.fn(),
    replace: mockReplace,
  }),
}));

jest.mock('@clerk/expo', () => ({
  useSignUp: () => mockUseSignUp(),
  useClerk: () => mockUseClerk(),
  useAuth: () => mockUseAuth(),
  isClerkAPIResponseError: (error: unknown) => mockIsClerkAPIResponseError(error),
}));

jest.mock('@/utils/app-user-linking', () => ({
  linkAppUser: (...args: unknown[]) => mockLinkAppUser(...args),
}));

const renderVerifyEmailScreen = () =>
  render(
    <SafeAreaProvider
      initialMetrics={{
        frame: { x: 0, y: 0, width: 390, height: 844 },
        insets: { top: 47, right: 0, bottom: 34, left: 0 },
      }}>
      <VerifyEmailScreen />
    </SafeAreaProvider>
  );

describe('Verify Email screen', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(Alert, 'alert').mockImplementation(jest.fn());
    clearPendingAuthFlow();
    mockIsClerkAPIResponseError.mockReturnValue(false);

    mockUseSignUp.mockReturnValue({
      isLoaded: true,
      signUp: {
        attemptEmailAddressVerification: mockAttemptEmailAddressVerification,
        prepareEmailAddressVerification: mockPrepareEmailVerification,
        status: 'missing_requirements',
      },
    });
    mockUseClerk.mockReturnValue({
      setActive: mockSetActive,
      user: {
        id: 'user_123',
      },
    });
    mockUseAuth.mockReturnValue({
      getToken: mockGetToken,
    });
    mockGetToken.mockResolvedValue('clerk-session-token');
    mockLinkAppUser.mockResolvedValue({
      id: 'app_user_123',
      clerk_user_id: 'user_123',
      email: 'user@example.com',
      display_name: null,
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    });
    mockPrepareEmailVerification.mockResolvedValue(undefined);
    setPendingAuthFlow({
      emailAddress: 'user@example.com',
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    clearPendingAuthFlow();
    jest.useRealTimers();
  });

  test('renders the verification UI and keeps the code input numeric and capped at six digits', () => {
    renderVerifyEmailScreen();

    expect(screen.getByText('Check your email')).toBeOnTheScreen();
    expect(
      screen.getByText('Enter the 6-digit code we sent to user@example.com.')
    ).toBeOnTheScreen();
    expect(screen.getAllByTestId('verification-code-box')).toHaveLength(6);
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeDisabled();
    expect(screen.getByRole('button', { name: "Didn't get it? Resend code" })).toBeEnabled();

    const codeInput = screen.getByLabelText('Verification code');
    fireEvent.changeText(codeInput, '12a3-4567');

    expect(codeInput).toHaveDisplayValue('123456');
    expect(screen.getAllByTestId('verification-code-box')[0]).toHaveTextContent('1');
    expect(screen.getAllByTestId('verification-code-box')[5]).toHaveTextContent('6');
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeEnabled();
  });

  test('resends the verification email, disables both actions while sending, and starts the cooldown', async () => {
    let resolvePrepare: (() => void) | undefined;

    mockPrepareEmailVerification.mockReturnValue(
      new Promise<void>((resolve) => {
        resolvePrepare = resolve;
      })
    );

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: "Didn't get it? Resend code" }));

    expect(screen.getByRole('button', { name: 'Resending...' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeDisabled();

    resolvePrepare?.();

    await waitFor(() => {
      expect(mockPrepareEmailVerification).toHaveBeenCalledWith({
        strategy: 'email_code',
      });
      expect(screen.getByRole('button', { name: 'Resend in 30s' })).toBeDisabled();
    });
  });

  test('counts down the resend cooldown and restores the resend action after 30 seconds', async () => {
    jest.useFakeTimers();
    mockPrepareEmailVerification.mockResolvedValue(undefined);

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: "Didn't get it? Resend code" }));

    await act(async () => {
      await Promise.resolve();
    });

    expect(screen.getByRole('button', { name: 'Resend in 30s' })).toBeDisabled();

    act(() => {
      jest.advanceTimersByTime(29000);
    });

    expect(screen.getByRole('button', { name: 'Resend in 1s' })).toBeDisabled();

    act(() => {
      jest.advanceTimersByTime(1000);
    });

    expect(screen.getByRole('button', { name: "Didn't get it? Resend code" })).toBeEnabled();
  });

  test('activates the session, links the app user, and advances on successful verification', async () => {
    mockAttemptEmailAddressVerification.mockResolvedValue({
      createdSessionId: 'session_123',
      createdUserId: 'user_123',
      status: 'complete',
    });

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    await waitFor(() => {
      expect(mockAttemptEmailAddressVerification).toHaveBeenCalledWith({
        code: '123456',
      });
      expect(mockSetActive).toHaveBeenCalledWith({ session: 'session_123' });
      expect(mockLinkAppUser).toHaveBeenCalledWith({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken: mockGetToken,
      });
      expect(mockReplace).toHaveBeenCalledWith('/trial-paywall');
    });
  });

  test('shows setup recovery after Supabase linking fails and retries without repeating verification', async () => {
    mockAttemptEmailAddressVerification.mockResolvedValue({
      createdSessionId: 'session_123',
      createdUserId: 'user_123',
      status: 'complete',
    });
    mockLinkAppUser.mockRejectedValueOnce(new Error('Supabase unavailable'));

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    await waitFor(() => {
      expect(
        screen.getByText('We could not finish setting up your account. Please try again.')
      ).toBeOnTheScreen();
      expect(screen.getByRole('button', { name: 'Finish setup' })).toBeEnabled();
    });

    expect(mockAttemptEmailAddressVerification).toHaveBeenCalledTimes(1);
    expect(mockLinkAppUser).toHaveBeenCalledTimes(1);

    fireEvent.press(screen.getByRole('button', { name: 'Finish setup' }));

    await waitFor(() => {
      expect(mockAttemptEmailAddressVerification).toHaveBeenCalledTimes(1);
      expect(mockLinkAppUser).toHaveBeenCalledTimes(2);
      expect(mockLinkAppUser).toHaveBeenLastCalledWith({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken: mockGetToken,
      });
      expect(mockReplace).toHaveBeenCalledWith('/trial-paywall');
    });
  });

  test('shows inline verification errors instead of alerts when Clerk rejects the code', async () => {
    mockIsClerkAPIResponseError.mockReturnValue(true);
    mockAttemptEmailAddressVerification.mockRejectedValue({
      errors: [
        {
          code: 'verification_failed',
          longMessage: 'That code is not valid.',
          message: 'Invalid code',
        },
      ],
    });

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    await waitFor(() => {
      expect(screen.getByText('That code is not valid.')).toBeOnTheScreen();
    });

    expect(screen.getByLabelText('Verification code')).toHaveDisplayValue('');
    expect(screen.getByText('Enter the 6-digit code we sent to user@example.com.')).toBeOnTheScreen();
    expect(Alert.alert).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalledWith('/trial-paywall');
  });

  test('shows inline resend errors instead of alerts when Clerk rejects the resend request', async () => {
    mockIsClerkAPIResponseError.mockReturnValue(true);
    mockPrepareEmailVerification.mockRejectedValue({
      errors: [
        {
          code: 'verification_unavailable',
          longMessage: 'The verification email could not be resent.',
          message: 'Verification email unavailable',
        },
      ],
    });

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: "Didn't get it? Resend code" }));

    await waitFor(() => {
      expect(screen.getByText('The verification email could not be resent.')).toBeOnTheScreen();
    });

    expect(Alert.alert).not.toHaveBeenCalled();
    expect(mockPrepareEmailVerification).toHaveBeenCalledWith({
      strategy: 'email_code',
    });
  });

  test('replaces the route when verification context is missing', async () => {
    clearPendingAuthFlow();

    renderVerifyEmailScreen();

    await waitFor(() => {
      expect(mockReplace).toHaveBeenCalledWith('/create-account');
    });

    expect(getPendingAuthFlow()).toBeNull();
  });

  test('replaces the route when Clerk sign-up state is missing', async () => {
    mockUseSignUp.mockReturnValue({
      isLoaded: true,
      signUp: null,
    });

    renderVerifyEmailScreen();

    await waitFor(() => {
      expect(mockReplace).toHaveBeenCalledWith('/create-account');
    });

    expect(getPendingAuthFlow()).toBeNull();
  });
});
