import type { AssessmentDraftAnswers } from '@/types/assessment';

export type ProgramLibraryEntry = {
  number: number;
  name: string;
  slug: string;
  bestFor: string;
  weeklySchedule: string;
  recommendedDaysPerWeekMin: number | null;
  recommendedDaysPerWeekMax: number | null;
  workoutCount: number;
};

export type ProgramSelectionLevel = 'beginner' | 'late_beginner' | 'intermediate' | 'advanced';

export type ProgramLibrary = {
  programs: ProgramLibraryEntry[];
  selectionGroups: Record<ProgramSelectionLevel, string[]>;
};

export type CompleteAssessmentDraft = {
  [Key in keyof AssessmentDraftAnswers]-?: NonNullable<AssessmentDraftAnswers[Key]>;
};

export type InternalTrainingLevel = ProgramSelectionLevel;
export type HitReadiness = 'new_to_hit' | 'learning_hit' | 'ready_for_hit' | 'experienced_hit';
export type RecoveryCapacity = 'good' | 'average' | 'limited';

export type ProgramRecommendation = {
  program: ProgramLibraryEntry;
  internalAssessment: {
    trainingLevel: InternalTrainingLevel;
    hitReadiness: HitReadiness;
    recoveryCapacity: RecoveryCapacity;
  };
  startingEffort: '8-9' | '9' | '9-10' | '10 selectively';
  recoveryDemand: 'low' | 'moderate' | 'high' | 'very_high';
  whyItFits: string[];
  afterCycle: string;
};
