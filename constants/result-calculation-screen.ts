import type { MessageSequenceState } from '@/types/result-calculation-screen';

export const RESULT_CALCULATION_SCREEN_OPTIONS = { gestureEnabled: false };

export const INITIAL_MESSAGE_SEQUENCE_STATE: MessageSequenceState = {
  activeMessageIndex: 0,
  hasCompleted: false,
};
