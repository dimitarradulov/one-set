import type { AppUserRow } from '@/types/supabase';

import { APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE } from '@/constants/app-user-setup';
import { createClerkSupabaseClient } from '@/utils/supabase';

type LinkAppUserInput = {
  clerkUserId: string;
  email: string;
  displayName?: string | null;
  getToken: () => Promise<string | null>;
};

const POSTGREST_JWT_CONFIGURATION_ERROR_CODE = 'PGRST301';

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const readString = (value: unknown): string | null => (typeof value === 'string' ? value : null);

const getPostgrestErrorCode = (error: unknown): string | null =>
  isRecord(error) ? readString(error.code) : null;

export class AppUserLinkingAuthConfigurationError extends Error {
  code = POSTGREST_JWT_CONFIGURATION_ERROR_CODE;

  constructor(cause?: unknown) {
    super(APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE);
    this.name = 'AppUserLinkingAuthConfigurationError';
    this.cause = cause;
  }
}

export const isAppUserLinkingAuthConfigurationError = (error: unknown): boolean =>
  error instanceof AppUserLinkingAuthConfigurationError ||
  getPostgrestErrorCode(error) === POSTGREST_JWT_CONFIGURATION_ERROR_CODE;

export const getAppUserLinkingErrorMessage = (error: unknown, fallback: string): string =>
  isAppUserLinkingAuthConfigurationError(error)
    ? APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE
    : fallback;

export const linkAppUser = async ({
  clerkUserId,
  email,
  displayName = null,
  getToken,
}: LinkAppUserInput): Promise<AppUserRow> => {
  const supabase = createClerkSupabaseClient(getToken);
  let lastError: unknown = null;

  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const { data, error } = await supabase
        .from('app_users')
        .upsert(
          {
            clerk_user_id: clerkUserId,
            email,
            display_name: displayName,
          },
          {
            onConflict: 'clerk_user_id',
          }
        )
        .select('id, clerk_user_id, email, display_name, created_at, updated_at')
        .single();

      if (error) {
        if (isAppUserLinkingAuthConfigurationError(error)) {
          throw new AppUserLinkingAuthConfigurationError(error);
        }

        lastError = error;
        continue;
      }

      if (data) {
        return data;
      }

      lastError = new Error('Supabase did not return an app user record.');
    } catch (error) {
      if (isAppUserLinkingAuthConfigurationError(error)) {
        throw error;
      }

      lastError = error;
    }
  }

  throw lastError ?? new Error('Supabase did not return an app user record.');
};
