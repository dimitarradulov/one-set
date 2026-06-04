import { fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import CreateAccountScreen from '../create-account';
import { clearPendingAuthFlow, getPendingAuthFlow } from '@/utils/pending-auth-flow';

const mockPush = jest.fn();
const mockReplace = jest.fn();
const mockBack = jest.fn();
const mockCanGoBack = jest.fn(() => false);
const mockCreate = jest.fn();
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
    canGoBack: mockCanGoBack,
    push: mockPush,
    replace: mockReplace,
    back: mockBack,
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

    mockUseSignUp.mockReturnValue({
      isLoaded: true,
      signUp: {
        create: mockCreate,
        prepareEmailAddressVerification: mockPrepareEmailVerification,
        status: 'complete',
        unverifiedFields: [],
        missingFields: [],
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
    mockIsClerkAPIResponseError.mockReturnValue(false);
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
    expect(mockCreate).not.toHaveBeenCalled();
    expect(Alert.alert).not.toHaveBeenCalledWith(
      'Account creation unavailable',
      expect.any(String)
    );
  });

  test('disables the create action while the account request is in flight', async () => {
    let resolveCreate:
      | ((value: { createdSessionId: string; createdUserId: string }) => void)
      | undefined;

    mockCreate.mockReturnValue(
      new Promise<{ createdSessionId: string; createdUserId: string }>((resolve) => {
        resolveCreate = resolve;
      })
    );

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), '  USER@Example.COM ');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    expect(screen.getByRole('button', { name: 'Creating account...' })).toBeDisabled();

    resolveCreate?.({
      createdSessionId: 'session_123',
      createdUserId: 'user_123',
    });

    await waitFor(() => {
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

  test('activates the session, links the app user, and advances on success', async () => {
    mockCreate.mockResolvedValue({
      createdSessionId: 'session_123',
      createdUserId: 'user_123',
    });

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), '  USER@Example.COM ');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(mockCreate).toHaveBeenCalledWith({
        emailAddress: 'user@example.com',
        password: 'secret1',
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

  test('routes to email verification and stores pending context when Clerk requires it', async () => {
    mockUseSignUp.mockReturnValue({
      isLoaded: true,
      signUp: {
        create: mockCreate,
        prepareEmailAddressVerification: mockPrepareEmailVerification,
        status: 'missing_requirements',
        unverifiedFields: ['email_address'],
        missingFields: [],
      },
    });

    mockCreate.mockResolvedValue({
      createdSessionId: null,
      createdUserId: 'user_123',
      status: 'missing_requirements',
      unverifiedFields: ['email_address'],
      missingFields: [],
    });
    mockPrepareEmailVerification.mockResolvedValue(undefined);

    renderCreateAccountScreen();

    fireEvent.changeText(screen.getByPlaceholderText('Email address'), '  USER@Example.COM ');
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'secret1');
    fireEvent.press(screen.getByRole('button', { name: 'Create account' }));

    await waitFor(() => {
      expect(mockCreate).toHaveBeenCalledWith({
        emailAddress: 'user@example.com',
        password: 'secret1',
      });
      expect(mockPrepareEmailVerification).toHaveBeenCalledWith({
        strategy: 'email_code',
      });
      expect(getPendingAuthFlow()).toEqual({
        emailAddress: 'user@example.com',
      });
      expect(mockSetActive).not.toHaveBeenCalled();
      expect(mockLinkAppUser).not.toHaveBeenCalled();
      expect(mockReplace).toHaveBeenCalledWith('/verify-email');
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

    mockIsClerkAPIResponseError.mockReturnValue(true);
    mockCreate.mockRejectedValue(clerkError);

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
