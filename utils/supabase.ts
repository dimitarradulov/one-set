import { createClient } from '@supabase/supabase-js';

import type { Database } from '@/types/supabase';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

const requireSupabaseUrl = (): string => {
  if (!supabaseUrl) {
    if (process.env.NODE_ENV === 'test') {
      return 'https://test.supabase.local';
    }

    throw new Error('EXPO_PUBLIC_SUPABASE_URL is not defined.');
  }

  return supabaseUrl;
};

const requireSupabaseAnonKey = (): string => {
  if (!supabaseAnonKey) {
    if (process.env.NODE_ENV === 'test') {
      return 'test-supabase-anon-key';
    }

    throw new Error('EXPO_PUBLIC_SUPABASE_ANON_KEY is not defined.');
  }

  return supabaseAnonKey;
};

const createConfiguredSupabaseClient = (options?: { accessToken?: () => Promise<string | null> }) =>
  createClient<Database>(requireSupabaseUrl(), requireSupabaseAnonKey(), options);

export const supabase = createConfiguredSupabaseClient();

export const createClerkSupabaseClient = (getToken: () => Promise<string | null>) =>
  createConfiguredSupabaseClient({ accessToken: getToken });
