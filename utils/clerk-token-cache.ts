import type { TokenCache } from '@clerk/expo';

const memoryTokens = new Map<string, string>();

const memoryTokenCache: TokenCache = {
  getToken: async (key: string) => memoryTokens.get(key) ?? null,
  saveToken: async (key: string, token: string) => {
    memoryTokens.set(key, token);
  },
  clearToken: (key: string) => {
    memoryTokens.delete(key);
  },
};

const loadNativeTokenCache = (): TokenCache => {
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { tokenCache } = require('@clerk/expo/token-cache') as {
      tokenCache?: TokenCache;
    };

    return tokenCache ?? memoryTokenCache;
  } catch {
    return memoryTokenCache;
  }
};

export const clerkTokenCache =
  process.env.NODE_ENV === 'test' ? memoryTokenCache : loadNativeTokenCache();
