import type { ProgramRecommendation } from '@/types/program';

export const RECOVERY_DEMAND_LABELS: Record<ProgramRecommendation['recoveryDemand'], string> = {
  low: 'Low',
  moderate: 'Moderate',
  high: 'High',
  very_high: 'Very high',
};

export const INTERNAL_ASSESSMENT_TERMS =
  /(internal training level|hit readiness|recovery capacity|trainingLevel|hitReadiness|recoveryCapacity)/i;

export const DEFAULT_FIT_REASON =
  'Built around your assessment answers, schedule, and available equipment.';
