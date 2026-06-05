import { createClerkSupabaseClient } from '../supabase';
import { APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE } from '@/constants/app-user-setup';
import { linkAppUser } from '../app-user-linking';

jest.mock('@supabase/supabase-js', () => {
  const mockSingle = jest.fn();
  const mockSelect = jest.fn(() => ({
    single: mockSingle,
  }));
  const mockUpsert = jest.fn(() => ({
    select: mockSelect,
  }));
  const mockFrom = jest.fn(() => ({
    upsert: mockUpsert,
  }));
  const mockClient = {
    from: mockFrom,
  };
  const createClient = jest.fn(() => mockClient);

  return {
    createClient,
    __mockSupabase: {
      createClient,
      mockClient,
      mockFrom,
      mockSingle,
      mockSelect,
      mockUpsert,
    },
  };
});

const supabaseMock = jest.requireMock('@supabase/supabase-js') as {
  __mockSupabase: {
    createClient: jest.Mock;
    mockClient: {
      from: jest.Mock;
    };
    mockFrom: jest.Mock;
    mockSingle: jest.Mock;
    mockSelect: jest.Mock;
    mockUpsert: jest.Mock;
  };
};

describe('app user linking', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    supabaseMock.__mockSupabase.mockSingle.mockReset();
  });

  test('creates a Clerk-aware Supabase client with the active token source', () => {
    const getToken = jest.fn();

    createClerkSupabaseClient(getToken);

    const [, , options] = supabaseMock.__mockSupabase.createClient.mock.calls.at(-1) ?? [];

    expect(options).toMatchObject({
      accessToken: getToken,
    });
  });

  test('upserts the app user keyed by clerk_user_id and returns the row', async () => {
    const getToken = jest.fn();
    const appUser = {
      id: 'app_user_123',
      clerk_user_id: 'user_123',
      email: 'user@example.com',
      display_name: null,
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    };

    supabaseMock.__mockSupabase.mockSingle.mockResolvedValue({
      data: appUser,
      error: null,
    });

    await expect(
      linkAppUser({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken,
      })
    ).resolves.toEqual(appUser);

    expect(supabaseMock.__mockSupabase.createClient).toHaveBeenCalled();
    expect(supabaseMock.__mockSupabase.mockFrom).toHaveBeenCalledWith('app_users');
    expect(supabaseMock.__mockSupabase.mockUpsert).toHaveBeenCalledWith(
      {
        clerk_user_id: 'user_123',
        display_name: null,
        email: 'user@example.com',
      },
      {
        onConflict: 'clerk_user_id',
      }
    );
  });

  test('retries transient Supabase failures twice before succeeding', async () => {
    const getToken = jest.fn();
    const appUser = {
      id: 'app_user_123',
      clerk_user_id: 'user_123',
      email: 'user@example.com',
      display_name: null,
      created_at: '2026-06-04T00:00:00Z',
      updated_at: '2026-06-04T00:00:00Z',
    };

    supabaseMock.__mockSupabase.mockSingle
      .mockResolvedValueOnce({
        data: null,
        error: new Error('temporary failure'),
      })
      .mockResolvedValueOnce({
        data: null,
        error: new Error('still failing'),
      })
      .mockResolvedValueOnce({
        data: appUser,
        error: null,
      });

    await expect(
      linkAppUser({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken,
      })
    ).resolves.toEqual(appUser);

    expect(supabaseMock.__mockSupabase.mockUpsert).toHaveBeenCalledTimes(3);
  });

  test('throws after exhausting the internal Supabase retries', async () => {
    const getToken = jest.fn();

    supabaseMock.__mockSupabase.mockSingle.mockResolvedValue({
      data: null,
      error: new Error('permanent failure'),
    });

    await expect(
      linkAppUser({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken,
      })
    ).rejects.toThrow('permanent failure');

    expect(supabaseMock.__mockSupabase.mockUpsert).toHaveBeenCalledTimes(3);
  });

  test('throws Supabase JWT configuration errors without retrying', async () => {
    const getToken = jest.fn();

    supabaseMock.__mockSupabase.mockSingle.mockResolvedValue({
      data: null,
      error: {
        code: 'PGRST301',
        details: 'No suitable key was found to decode the JWT',
        hint: null,
        message: 'No suitable key or wrong key type',
      },
    });

    await expect(
      linkAppUser({
        clerkUserId: 'user_123',
        email: 'user@example.com',
        displayName: null,
        getToken,
      })
    ).rejects.toThrow(APP_USER_SETUP_AUTH_CONFIGURATION_MESSAGE);

    expect(supabaseMock.__mockSupabase.mockUpsert).toHaveBeenCalledTimes(1);
  });
});
