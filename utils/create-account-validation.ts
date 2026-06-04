import type {
  CreateAccountInput,
  CreateAccountValidationErrors,
} from '@/types/create-account-validation';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const normalizeCreateAccountEmail = (email: string): string => email.trim().toLowerCase();

export const validateCreateAccountInput = ({
  email,
  password,
}: CreateAccountInput): CreateAccountValidationErrors => {
  const normalizedEmail = normalizeCreateAccountEmail(email);
  const errors: CreateAccountValidationErrors = {};

  if (!normalizedEmail) {
    errors.email = 'Enter your email address.';
  } else if (!EMAIL_PATTERN.test(normalizedEmail)) {
    errors.email = 'Enter a valid email address.';
  }

  if (password.length < 6) {
    errors.password = 'Password must be at least 6 characters.';
  }

  return errors;
};
