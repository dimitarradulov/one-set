import type {
  CreateAccountActionId,
  CreateAccountUnavailableAlert,
} from '@/types/create-account-actions';

export const CREATE_ACCOUNT_UNAVAILABLE_ALERTS: Record<
  CreateAccountActionId,
  CreateAccountUnavailableAlert
> = {
  apple: {
    title: 'Apple sign in unavailable',
    message: 'Sign in with Apple is not configured in this build yet.',
  },
  'create-account': {
    title: 'Account creation unavailable',
    message: 'Email account creation is not connected in this build yet.',
  },
  'sign-in': {
    title: 'Sign in unavailable',
    message: 'Returning-user sign in is not connected in this build yet.',
  },
};
