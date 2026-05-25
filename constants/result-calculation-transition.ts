export const RESULT_CALCULATION_MESSAGES = [
  'Analyzing your training level…',
  'Matching your recovery profile…',
  'Selecting your HIT frequency…',
  'Building your starter program…',
] as const;

export const RESULT_CALCULATION_MESSAGE_DURATION_MS = 900;

export const RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS =
  RESULT_CALCULATION_MESSAGES.length * RESULT_CALCULATION_MESSAGE_DURATION_MS;
