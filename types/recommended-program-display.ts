import type { ProgramRecommendation } from '@/types/program';

export type RecommendedProgramDisplayFacts = {
  programName: string;
  daysPerWeek: string;
  estimatedWorkoutLength: string;
  startingEffort: ProgramRecommendation['startingEffort'];
  recoveryDemand: string;
  whyItFits: string[];
  afterCycle: string;
};
