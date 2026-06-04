import type { PendingAuthFlow } from '@/types/pending-auth-flow';

let pendingAuthFlow: PendingAuthFlow | null = null;

export const setPendingAuthFlow = (flow: PendingAuthFlow): void => {
  pendingAuthFlow = flow;
};

export const getPendingAuthFlow = (): PendingAuthFlow | null => pendingAuthFlow;

export const clearPendingAuthFlow = (): void => {
  pendingAuthFlow = null;
};
