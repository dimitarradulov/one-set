import {
  DEFAULT_FIT_REASON,
  INTERNAL_ASSESSMENT_TERMS,
  RECOVERY_DEMAND_LABELS,
} from '@/constants/recommended-program-display';
import type { SessionLengthId } from '@/types/assessment';
import type { ProgramLibraryEntry, ProgramRecommendation } from '@/types/program';
import type { RecommendedProgramDisplayFacts } from '@/types/recommended-program-display';

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

export const sanitizeProgramFitReasons = (reasons: string[]): string[] => {
  const sanitizedReasons = reasons
    .map((reason) => reason.trim())
    .filter((reason) => reason.length > 0)
    .filter((reason) => !INTERNAL_ASSESSMENT_TERMS.test(reason));

  return sanitizedReasons.length > 0 ? sanitizedReasons : [DEFAULT_FIT_REASON];
};

export const buildRecommendedProgramDisplayFacts = (
  recommendation: ProgramRecommendation,
  preferredSessionLength: SessionLengthId | null
): RecommendedProgramDisplayFacts => ({
  programName: recommendation.program.name,
  daysPerWeek: formatProgramDaysPerWeek(recommendation.program),
  estimatedWorkoutLength: formatProgramWorkoutLength(preferredSessionLength),
  startingEffort: recommendation.startingEffort,
  recoveryDemand: formatProgramRecoveryDemand(recommendation.recoveryDemand),
  whyItFits: sanitizeProgramFitReasons(recommendation.whyItFits),
  afterCycle: recommendation.afterCycle,
});
