import { isClerkAPIResponseError } from '@clerk/expo';

import type { CreateAccountValidationField } from '@/types/create-account-validation';
import type {
  ClerkAuthMethodResult,
  ClerkEmailPasswordSignUp,
  ClerkTokenGetter,
} from '@/types/clerk-sign-up-flow';
import { linkAppUser } from '@/utils/app-user-linking';

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const readString = (value: unknown): string | null => (typeof value === 'string' ? value : null);

const readClerkErrorPayload = (error: unknown): Record<string, unknown> | null => {
  if (isClerkAPIResponseError(error)) {
    const firstError: unknown = error.errors[0] ?? null;

    return isRecord(firstError) ? firstError : null;
  }

  if (!isRecord(error)) {
    return null;
  }

  const nestedErrors = error.errors;

  if (Array.isArray(nestedErrors) && isRecord(nestedErrors[0])) {
    return nestedErrors[0];
  }

  return error;
};

export const getAuthMethodError = (result: ClerkAuthMethodResult): unknown | null => {
  if (!isRecord(result) || !('error' in result)) {
    return null;
  }

  return result.error ?? null;
};

export const getClerkErrorMessage = (error: unknown, fallback: string): string => {
  const payload = readClerkErrorPayload(error);

  return (
    readString(payload?.longMessage) ??
    readString(payload?.message) ??
    readString(error) ??
    fallback
  );
};

export const getClerkErrorTarget = (error: unknown): CreateAccountValidationField => {
  const payload = readClerkErrorPayload(error);
  const code = readString(payload?.code)?.toLowerCase() ?? '';
  const meta = isRecord(payload?.meta) ? payload.meta : null;
  const paramName = readString(meta?.paramName)?.toLowerCase() ?? '';

  if (
    code.includes('identifier') ||
    code.includes('email') ||
    paramName.includes('email') ||
    paramName.includes('identifier')
  ) {
    return 'email';
  }

  if (code.includes('password') || paramName.includes('password')) {
    return 'password';
  }

  return 'form';
};

export const getSessionClerkUserId = (session: unknown): string | null => {
  if (!isRecord(session)) {
    return null;
  }

  const user = isRecord(session.user) ? session.user : null;
  const actor = isRecord(session.actor) ? session.actor : null;

  return (
    readString(user?.id) ??
    readString(session.userId) ??
    readString(session.user_id) ??
    readString(actor?.sub) ??
    null
  );
};

export const finalizeClerkSignUp = async (signUp: ClerkEmailPasswordSignUp): Promise<string> => {
  let finalizedClerkUserId: string | null = null;

  await signUp.finalize({
    navigate: async ({ session }) => {
      finalizedClerkUserId = getSessionClerkUserId(session);
    },
  });

  if (!finalizedClerkUserId) {
    throw new Error('Clerk finalized sign-up without a user id.');
  }

  return finalizedClerkUserId;
};

export const linkFinalizedClerkSignUp = async ({
  clerkUserId,
  email,
  getToken,
}: {
  clerkUserId: string;
  email: string;
  getToken: ClerkTokenGetter;
}) => {
  await linkAppUser({
    clerkUserId,
    email,
    displayName: null,
    getToken,
  });
};
