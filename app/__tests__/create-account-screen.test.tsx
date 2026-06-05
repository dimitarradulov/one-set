import { fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import CreateAccountScreen from '../create-account';
import { APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE } from '@/constants/app-user-setup';
import { clearPendingAuthFlow, getPendingAuthFlow } from '@/utils/pending-auth-flow';

const mockPush = jest.fn();
const mockReplace = jest.fn();
const mockBack = jest.fn();
const mockCanGoBack = jest.fn(() => false);
const mockPassword = jest.fn();
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
  password: typeof mockPassword;
  verifications: {
    sendEmailCode: typeof mockSendEmailCode;
    verifyEmailCode: jest.Mock;
  };
  finalize: typeof mockFinalize;
};

jest.mock('expo-router', () => ({
  useRouter: () => ({
    canGoBack: mockCanGoBack,
    push: mockPush,
    replace: mockReplace,
    back: mockBack,
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

    mockSignUp = {
      status: 'missing_requirements',
      password: mockPassword,
      verifications: {
        sendEmailCode: mockSendEmailCode,
        verifyEmailCode: jest.fn(),
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
    mockPassword.mockResolvedValue({ error: null });
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
    mockGetToken.mockResolvedValue('clerk-session-token');
    mockLinkAppUser.mockResolvedValue({
      id: 'app_user_123',
      clerk_user_id: 'user_123',
      email: 'user@example.com',
      display_name: null,
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    });
    clearPendingAuthFlow();
  });

  afterEach(() => {
    jest.restoreAllMocks();
    clearPendingAuthFlow();
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
    expect(screen.getByText('Email address')).toBeOnTheScreen();
    expect(screen.getByPlaceholderText('Email address')).toBeOnTheScreen();
    expect(screen.getByText('Password')).toBeOnTheScreen();
    expect(screen.getByPlaceholderText('Password')).toBeOnTheScreen();
    expect(screen.getByRole('button', { name: 'Create account' })).toBeOnTheScreen();
    expect(screen.getByTestId('clerk-captcha')).toBeOnTheScreen();
    expect(
      screen.getByRole('button', { name: 'Already have an account? Sign in.' })
    ).toBeOnTheScreen();
    expect(screen.getByText('Free to start. No payment required.')).toBeOnTheScreen();
  });

  test('keeps account placeholders unavailable and does not navigate', () => {
    renderCreateAccountScreen();

    fireEvent.press(screen.getByRole('button', { name: 'Continue with Apple' }));
    expect(Alert.alert).toHaveBeenCalledWith(
      'Apple sign in unavailable',
      'Sign in with Apple is not configured in this build yet.'
    );

    fireEvent.press(screen.getByRole('button', { name: 'Already have an account? Sign in.' }));
    expect(Alert.alert).toHaveBeenCalledWith(
      'Sign in unavailable',
      'Returning-user sign in is not connected in this build yet.'
    );

    expect(mockReplace).not.toHaveBeenCalled();
    expect(mockPush).not.toHaveBeenCalled();
    expect(mockBack).not.toHaveBeenCalled();
  });

  test('shows inline validation errors and does not call Clerk for invalid credentials', () => {
    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), 'invalid-email');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), '12345');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    expect(screen.getByText('Enter a valid email address.')).toBeOnTheScreen();
    expect(screen.getByText('Password must be at least 6 characters.')).toBeOnTheScreen();
    expect(mockPassword).not.toHaveBeenCalled();
    expect(Alert.alert).not.toHaveBeenCalledWith(
      'Account creation unavailable',
      expect.any(String)
    );
  });

  test('disables the create action while the account request is in flight', async () => {
    let resolveCreate: ((value: { error: null }) => void) | undefined;

    mockPassword.mockReturnValue(
      new Promise<{ error: null }>((resolve) => {
        resolveCreate = resolve;
      })
    );

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), '  USER@Example.COM ');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    expect(screen.getByRole('button', { name: 'Creating account...' })).toBeDisabled();

    resolveCreate?.({ error: null });

    await waitFor(() => {
      expect(mockSendEmailCode).toHaveBeenCalled();
      expect(mockReplace).toHaveBeenCalledWith('/verify-email');
    });
  });

  test('starts email/password sign-up, sends the verification code, and routes to verification', async () => {
    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), '  USER@Example.COM ');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(mockPassword).toHaveBeenCalledWith({
        emailAddress: 'user@example.com',
        password: 'secret1',
      });
      expect(mockSendEmailCode).toHaveBeenCalled();
      expect(getPendingAuthFlow()).toEqual({
        emailAddress: 'user@example.com',
      });
      expect(mockFinalize).not.toHaveBeenCalled();
      expect(mockLinkAppUser).not.toHaveBeenCalled();
      expect(mockReplace).toHaveBeenCalledWith('/verify-email');
    });
  });

  test('shows setup recovery after Supabase linking fails and retries without recreating the account', async () => {
    mockSignUp.status = 'complete';
    mockLinkAppUser.mockRejectedValueOnce(new Error('Supabase unavailable'));

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), 'user@example.com');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(
        screen.getByText('We could not finish setting up your account. Please try again.')
      ).toBeOnTheScreen();
      expect(screen.getByRole('button', { name: 'Finish setup' })).toBeEnabled();
    });

    expect(screen.getByPlaceholderText('Password')).toHaveDisplayValue('');
    expect(mockPassword).toHaveBeenCalledTimes(1);
    expect(mockFinalize).toHaveBeenCalledTimes(1);
    expect(mockSendEmailCode).not.toHaveBeenCalled();
    expect(mockLinkAppUser).toHaveBeenCalledTimes(1);

    fireEvent.press(screen.getByRole('button', { name: 'Finish setup' }));

    await waitFor(() => {
      expect(mockPassword).toHaveBeenCalledTimes(1);
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

  test('explains Supabase JWT configuration errors during immediate setup linking', async () => {
    mockSignUp.status = 'complete';
    mockLinkAppUser.mockRejectedValueOnce({
      code: 'PGRST301',
      details: 'No suitable key was found to decode the JWT',
      hint: null,
      message: 'No suitable key or wrong key type',
    });

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), 'user@example.com');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(screen.getByText(APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE)).toBeOnTheScreen();
    });
  });

  test('finalizes and links immediately when Clerk completes sign-up without verification', async () => {
    mockSignUp.status = 'complete';
    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), '  USER@Example.COM ');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(mockPassword).toHaveBeenCalledWith({
        emailAddress: 'user@example.com',
        password: 'secret1',
      });
      expect(mockFinalize).toHaveBeenCalled();
      expect(mockLinkAppUser).toHaveBeenCalledWith({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken: mockGetToken,
      });
      expect(getPendingAuthFlow()).toBeNull();
      expect(mockReplace).toHaveBeenCalledWith('/trial-paywall');
    });
  });

  test('shows Clerk auth errors inline instead of using alerts', async () => {
    const clerkError = {
      errors: [
        {
          code: 'form_identifier_exists',
          longMessage: 'Email address already exists',
          message: 'Identifier exists',
        },
      ],
    };

    mockPassword.mockResolvedValue({ error: clerkError });

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), 'user@example.com');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(screen.getByText('Email address already exists')).toBeOnTheScreen();
    });

    expect(Alert.alert).not.toHaveBeenCalledWith(
      'Account creation unavailable',
      expect.any(String)
    );
    expect(mockReplace).not.toHaveBeenCalled();
  });
});
