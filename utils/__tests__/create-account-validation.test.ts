import {
  normalizeCreateAccountEmail,
  validateCreateAccountInput,
} from '../create-account-validation';

describe('create account validation', () => {
  test('trims and lowercases email addresses before submit', () => {
    expect(normalizeCreateAccountEmail('  TEST@Example.COM ')).toBe('test@example.com');
  });

  test('returns inline errors for invalid email and short password input', () => {
    expect(validateCreateAccountInput({ email: 'invalid-email', password: '12345' })).toEqual({
      email: 'Enter a valid email address.',
      password: 'Password must be at least 6 characters.',
    });
  });

  test('accepts a valid email and password pair', () => {
    expect(validateCreateAccountInput({ email: 'user@example.com', password: 'secret1' })).toEqual(
      {}
    );
  });
});
