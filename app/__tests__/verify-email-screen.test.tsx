import { fireEvent, render, screen, waitFor } from '@testing-library/react-native';
import { Alert } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import VerifyEmailScreen from '../verify-email';
import { clearPendingAuthFlow, setPendingAuthFlow } from '@/utils/pending-auth-flow';

const mockReplace = jest.fn();
const mockAttemptEmailAddressVerification = jest.fn();
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
    setPendingAuthFlow({
      emailAddress: 'user@example.com',
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    clearPendingAuthFlow();
  });

  test('renders the verification UI and keeps the code input numeric and capped at six digits', () => {
    renderVerifyEmailScreen();

    expect(screen.getByText('Check your email')).toBeOnTheScreen();
    expect(
      screen.getByText('Enter the 6-digit code we sent to user@example.com.')
    ).toBeOnTheScreen();
    expect(screen.getAllByTestId('verification-code-box')).toHaveLength(6);
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeDisabled();

    const codeInput = screen.getByLabelText('Verification code');
    fireEvent.changeText(codeInput, '12a3-4567');

    expect(codeInput).toHaveDisplayValue('123456');
    expect(screen.getAllByTestId('verification-code-box')[0]).toHaveTextContent('1');
    expect(screen.getAllByTestId('verification-code-box')[5]).toHaveTextContent('6');
    expect(screen.getByRole('button', { name: 'Verify email' })).toBeEnabled();
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

    expect(Alert.alert).not.toHaveBeenCalled();
    expect(mockReplace).not.toHaveBeenCalledWith('/trial-paywall');
  });

  test('replaces the route when verification context is missing', async () => {
    clearPendingAuthFlow();

    renderVerifyEmailScreen();

    await waitFor(() => {
      expect(mockReplace).toHaveBeenCalledWith('/create-account');
    });
  });
});
