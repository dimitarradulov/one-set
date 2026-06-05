export type ClerkAuthMethodResult =
  | {
      error?: unknown | null;
    }
  | null
  | undefined
  | void;

export type ClerkFinalizeNavigationParams = {
  session?: unknown;
  decorateUrl?: (href: string) => string;
};

export type ClerkEmailPasswordSignUp = {
  status?: string | null;
  missingFields?: string[];
  unverifiedFields?: string[];
  password: (input: { emailAddress: string; password: string }) => Promise<ClerkAuthMethodResult>;
  verifications: {
    sendEmailCode: () => Promise<ClerkAuthMethodResult>;
    verifyEmailCode: (input: { code: string }) => Promise<ClerkAuthMethodResult>;
  };
  finalize: (input: {
    navigate: (params: ClerkFinalizeNavigationParams) => Promise<void> | void;
  }) => Promise<unknown>;
};

export type CreateAccountNavigationHref = '/create-account' | '/trial-paywall' | '/verify-email';

export type CreateAccountNavigation = {
  replace: (href: CreateAccountNavigationHref) => void;
};

export type ClerkTokenGetter = () => Promise<string | null>;
