export type CreateAccountValidationField = 'email' | 'password' | 'form';

export type CreateAccountValidationErrors = Partial<Record<CreateAccountValidationField, string>>;

export type CreateAccountInput = {
  email: string;
  password: string;
};
