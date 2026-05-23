import type { SessionLengthId } from '@/types/assessment';
import type { ProgramLibraryEntry, ProgramRecommendation } from '@/types/program';

const RECOVERY_DEMAND_LABELS: Record<ProgramRecommendation['recoveryDemand'], string> = {
  low: 'Low',
  moderate: 'Moderate',
  high: 'High',
  very_high: 'Very high',
};

export type RecommendedProgramDisplayFacts = {
  programName: string;
  daysPerWeek: string;
  estimatedWorkoutLength: string;
  startingEffort: ProgramRecommendation['startingEffort'];
  recoveryDemand: string;
  whyItFits: string[];
  afterCycle: string;
};

export const formatProgramDaysPerWeek = (program: ProgramLibraryEntry): string => {
  const { recommendedDaysPerWeekMin, recommendedDaysPerWeekMax } = program;

  if (
    typeof recommendedDaysPerWeekMin !== 'number' ||
    typeof recommendedDaysPerWeekMax !== 'number'
  ) {
    return 'Varies by program cycle';
  }

  if (recommendedDaysPerWeekMin === recommendedDaysPerWeekMax) {
    const dayLabel = recommendedDaysPerWeekMin === 1 ? 'day' : 'days';

    return `${recommendedDaysPerWeekMin} ${dayLabel}/week`;
  }

  return `${recommendedDaysPerWeekMin}-${recommendedDaysPerWeekMax} days/week`;
};

export const formatProgramWorkoutLength = (
  preferredSessionLength: SessionLengthId | null
): string =>
  preferredSessionLength ? `${preferredSessionLength} minutes` : 'Use your selected session length';

export const formatProgramRecoveryDemand = (
  recoveryDemand: ProgramRecommendation['recoveryDemand']
): string => RECOVERY_DEMAND_LABELS[recoveryDemand];

export const buildRecommendedProgramDisplayFacts = (
  recommendation: ProgramRecommendation,
  preferredSessionLength: SessionLengthId | null
): RecommendedProgramDisplayFacts => ({
  programName: recommendation.program.name,
  daysPerWeek: formatProgramDaysPerWeek(recommendation.program),
  estimatedWorkoutLength: formatProgramWorkoutLength(preferredSessionLength),
  startingEffort: recommendation.startingEffort,
  recoveryDemand: formatProgramRecoveryDemand(recommendation.recoveryDemand),
  whyItFits: recommendation.whyItFits,
  afterCycle: recommendation.afterCycle,
});
