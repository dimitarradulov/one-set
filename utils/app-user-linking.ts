import type { AppUserRow } from '@/types/supabase';

import { createClerkSupabaseClient } from '@/utils/supabase';

type LinkAppUserInput = {
  clerkUserId: string;
  email: string;
  displayName?: string | null;
  getToken: () => Promise<string | null>;
};

export const linkAppUser = async ({
  clerkUserId,
  email,
  displayName = null,
  getToken,
}: LinkAppUserInput): Promise<AppUserRow> => {
  const supabase = createClerkSupabaseClient(getToken);
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
    throw error;
  }

  if (!data) {
    throw new Error('Supabase did not return an app user record.');
  }

  return data;
};
