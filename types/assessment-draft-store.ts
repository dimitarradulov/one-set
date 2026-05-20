import type {
  AssessmentDraftAnswerKey,
  AssessmentDraftAnswers,
  FailureComfortId,
  LimitationId,
  MainGoalId,
} from '@/types/assessment';

export type AssessmentDraftPersistedState = AssessmentDraftAnswers;

export interface AssessmentDraftState extends AssessmentDraftPersistedState {
  isHydrated: boolean;
  setHydrated: (isHydrated: boolean) => void;
  commitMainGoal: (mainGoal: MainGoalId) => void;
  commitLimitations: (limitations: LimitationId[]) => void;
  commitFailureComfort: (failureComfort: FailureComfortId) => void;
  commitAnswer: <Key extends AssessmentDraftAnswerKey>(
    answerKey: Key,
    answer: AssessmentDraftAnswers[Key]
  ) => void;
}
