import { act, fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import VerifyEmailScreen from '../verify-email';
import { APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE } from '@/constants/app-user-setup';
import {
  clearPendingAuthFlow,
  getPendingAuthFlow,
  setPendingAuthFlow,
} from '@/utils/pending-auth-flow';

const mockReplace = jest.fn();
const mockVerifyEmailCode = jest.fn();
const mockSendEmailCode = jest.fn();
const mockFinalize = jest.fn();
const mockGetToken = jest.fn();
const mockLinkAppUser = jest.fn();
const mockUseSignUp = jest.fn();
const mockUseAuth = jest.fn();
let mockSignUp: {
  status: string;
  missingFields: string[];
  unverifiedFields: string[];
  password: jest.Mock;
  verifications: {
    sendEmailCode: typeof mockSendEmailCode;
    verifyEmailCode: typeof mockVerifyEmailCode;
  };
  finalize: typeof mockFinalize;
};

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
  useAuth: () => mockUseAuth(),
  isClerkAPIResponseError: (error: unknown) =>
    typeof error === 'object' && error !== null && 'errors' in error,
}));

jest.mock('@/utils/app-user-linking', () => ({
  ...jest.requireActual('@/utils/app-user-linking'),
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

    mockSignUp = {
      status: 'missing_requirements',
      password: jest.fn(),
      verifications: {
        sendEmailCode: mockSendEmailCode,
        verifyEmailCode: mockVerifyEmailCode,
      },
      unverifiedFields: ['email_address'],
      missingFields: [],
      finalize: mockFinalize,
    };
    mockUseSignUp.mockReturnValue({
      signUp: mockSignUp,
      fetchStatus: 'idle',
    });
    mockUseAuth.mockReturnValue({
      getToken: mockGetToken,
    });
    mockGetToken.mockResolvedValue('clerk-session-token');
    mockVerifyEmailCode.mockImplementation(async () => {
      mockSignUp.status = 'complete';
      return { error: null };
    });
    mockSendEmailCode.mockResolvedValue({ error: null });
    mockFinalize.mockImplementation(
      async ({
        navigate,
      }: {
        navigate: (params: { session: { user: { id: string } } }) => Promise<void> | void;
      }) => {
        await navigate({
          session: {
            user: {
              id: 'user_123',
            },
          },
        });
      }
    );
    mockLinkAppUser.mockResolvedValue({
      id: 'app_user_123',
      clerk_user_id: 'user_123',
      email: 'user@example.com',
      display_name: null,
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    });
    setPendingAuthFlow({
      emailAddress: 'user@example.com',
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    clearPendingAuthFlow();
    jest.useRealTimers();
  });

  test('renders the verification UI and keeps the visible code entry numeric and capped', () => {
    renderVerifyEmailScreen();

    expect(screen.getByText('Check your email')).toBeOnTheScreen();
    expect(
      screen.getByText('Enter the 6-digit code we sent to user@example.com.')
    ).toBeOnTheScreen();
    expect(screen.getAllByTestId('verification-code-box')).toHaveLength(6);
    fireEvent.press(screen.getByRole('button', { name: 'Verification code entry' }));
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeDisabled();
    expect(screen.getByRole('button', { name: "Didn't get it? Resend code" })).toBeEnabled();

    const codeInput = screen.getByLabelText('Verification code');
    expect(codeInput).toHaveProp('className', expect.stringContaining('h-px'));

    fireEvent.changeText(codeInput, '12a3-4567');

    expect(codeInput).toHaveDisplayValue('123456');
    expect(screen.getAllByTestId('verification-code-box')[0]).toHaveTextContent('1');
    expect(screen.getAllByTestId('verification-code-box')[5]).toHaveTextContent('6');
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeEnabled();
  });

  test('resends the verification email, disables both actions while sending, and starts the cooldown', async () => {
    let resolvePrepare: ((value: { error: null }) => void) | undefined;

    mockSendEmailCode.mockReturnValue(
      new Promise<{ error: null }>((resolve) => {
        resolvePrepare = resolve;
      })
    );

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: "Didn't get it? Resend code" }));

    expect(screen.getByRole('button', { name: 'Resending...' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeDisabled();

    resolvePrepare?.({ error: null });

    await waitFor(() => {
      expect(mockSendEmailCode).toHaveBeenCalled();
      expect(screen.getByRole('button', { name: 'Resend in 30s' })).toBeDisabled();
    });
  });

  test('shows the verifying loading state and disables resend while the code is in flight', async () => {
    let resolveAttempt: ((value: { error: null }) => void) | undefined;

    mockVerifyEmailCode.mockReturnValue(
      new Promise<{ error: null }>((resolve) => {
        resolveAttempt = resolve;
      })
    );

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    expect(screen.getByRole('button', { name: 'Verifying...' })).toBeDisabled();
    expect(screen.getByRole('button', { name: "Didn't get it? Resend code" })).toBeDisabled();

    mockSignUp.status = 'complete';
    resolveAttempt?.({ error: null });

    await waitFor(() => {
      expect(mockFinalize).toHaveBeenCalled();
      expect(mockLinkAppUser).toHaveBeenCalledWith({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken: mockGetToken,
      });
      expect(mockReplace).toHaveBeenCalledWith('/trial-paywall');
    });
  });

  test('counts down the resend cooldown and restores the resend action after 30 seconds', async () => {
    jest.useFakeTimers();
    mockSendEmailCode.mockResolvedValue({ error: null });

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

  test('finalizes the session, links the app user, and advances on successful verification', async () => {
    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    await waitFor(() => {
      expect(mockVerifyEmailCode).toHaveBeenCalledWith({
        code: '123456',
      });
      expect(mockFinalize).toHaveBeenCalled();
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

    expect(mockVerifyEmailCode).toHaveBeenCalledTimes(1);
    expect(mockFinalize).toHaveBeenCalledTimes(1);
    expect(mockLinkAppUser).toHaveBeenCalledTimes(1);

    fireEvent.press(screen.getByRole('button', { name: 'Finish setup' }));

    await waitFor(() => {
      expect(mockVerifyEmailCode).toHaveBeenCalledTimes(1);
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

  test('explains Supabase JWT configuration errors during setup linking', async () => {
    mockLinkAppUser.mockRejectedValueOnce({
      code: 'PGRST301',
      details: 'No suitable key was found to decode the JWT',
      hint: null,
      message: 'No suitable key or wrong key type',
    });

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    await waitFor(() => {
      expect(screen.getByText(APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE)).toBeOnTheScreen();
    });
  });

  test('shows inline verification errors instead of alerts when Clerk rejects the code', async () => {
    mockVerifyEmailCode.mockResolvedValue({
      error: {
        errors: [
          {
            code: 'verification_failed',
            longMessage: 'That code is not valid.',
            message: 'Invalid code',
          },
        ],
      },
    });

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: 'Verify email' }));

    await waitFor(() => {
      expect(screen.getByText('That code is not valid.')).toBeOnTheScreen();
    });

    expect(screen.getByLabelText('Verification code')).toHaveDisplayValue('');
    expect(
      screen.getByText('Enter the 6-digit code we sent to user@example.com.')
    ).toBeOnTheScreen();
    expect(Alert.alert).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalledWith('/trial-paywall');
  });

  test('shows inline resend errors instead of alerts when Clerk rejects the resend request', async () => {
    mockSendEmailCode.mockResolvedValue({
      error: {
        errors: [
          {
            code: 'verification_unavailable',
            longMessage: 'The verification email could not be resent.',
            message: 'Verification email unavailable',
          },
        ],
      },
    });

    renderVerifyEmailScreen();

    fireEvent.changeText(screen.getByLabelText('Verification code'), '123456');
    fireEvent.press(screen.getByRole('button', { name: "Didn't get it? Resend code" }));

    await waitFor(() => {
      expect(screen.getByText('The verification email could not be resent.')).toBeOnTheScreen();
    });

    expect(Alert.alert).not.toHaveBeenCalled();
    expect(mockSendEmailCode).toHaveBeenCalled();
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
      signUp: null,
    });

    renderVerifyEmailScreen();

    await waitFor(() => {
      expect(mockReplace).toHaveBeenCalledWith('/create-account');
    });

    expect(getPendingAuthFlow()).toBeNull();
  });
});
