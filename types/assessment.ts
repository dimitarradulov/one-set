import type { Href } from 'expo-router';

import type {
  DAYS_AVAILABLE_IDS,
  EQUIPMENT_ACCESS_IDS,
  FAILURE_COMFORT_IDS,
  HIT_EXPERIENCE_IDS,
  LIFESTYLE_STRESS_IDS,
  LIMITATION_IDS,
  MAIN_GOAL_IDS,
  RECOVERY_PROFILE_IDS,
  SESSION_LENGTH_IDS,
  TRAINING_DIRECTION_IDS,
  TRAINING_EXPERIENCE_IDS,
} from '@/constants/assessment-intake';

export type MainGoalId = (typeof MAIN_GOAL_IDS)[number];
export type TrainingExperienceId = (typeof TRAINING_EXPERIENCE_IDS)[number];
export type HitExperienceId = (typeof HIT_EXPERIENCE_IDS)[number];
export type DaysAvailableId = (typeof DAYS_AVAILABLE_IDS)[number];
export type SessionLengthId = (typeof SESSION_LENGTH_IDS)[number];
export type EquipmentAccessId = (typeof EQUIPMENT_ACCESS_IDS)[number];
export type RecoveryProfileId = (typeof RECOVERY_PROFILE_IDS)[number];
export type LifestyleStressId = (typeof LIFESTYLE_STRESS_IDS)[number];
export type LimitationId = (typeof LIMITATION_IDS)[number];
export type TrainingDirectionId = (typeof TRAINING_DIRECTION_IDS)[number];
export type FailureComfortId = (typeof FAILURE_COMFORT_IDS)[number];

export type AssessmentDraftAnswers = {
  mainGoal: MainGoalId | null;
  trainingExperience: TrainingExperienceId | null;
  hitExperience: HitExperienceId | null;
  daysAvailablePerWeek: DaysAvailableId | null;
  preferredSessionLength: SessionLengthId | null;
  equipmentAccess: EquipmentAccessId | null;
  recoveryProfile: RecoveryProfileId | null;
  lifestyleStress: LifestyleStressId | null;
  limitations: LimitationId[];
  trainingDirection: TrainingDirectionId | null;
  failureComfort: FailureComfortId | null;
};

export type AssessmentDraftAnswerKey = keyof AssessmentDraftAnswers;
export type AssessmentIntakeQuestionId =
  | 'main-goal'
  | 'training-experience'
  | 'hit-experience'
  | 'days-available'
  | 'session-length'
  | 'equipment-access'
  | 'recovery-profile'
  | 'lifestyle-stress'
  | 'limitations'
  | 'training-direction'
  | 'failure-comfort';

export type AssessmentOption<Value extends string> = {
  label: string;
  value: Value;
};

export type AssessmentIntakeQuestion<
  Id extends AssessmentIntakeQuestionId = AssessmentIntakeQuestionId,
  AnswerKey extends AssessmentDraftAnswerKey = AssessmentDraftAnswerKey,
  Value extends string = string,
> = {
  id: Id;
  answerKey: AnswerKey;
  selectionMode: 'single' | 'multiple';
  progressStep: number;
  route: Href;
  previousRoute: Href;
  nextRoute: Href;
  question: string;
  helperText: string;
  options: readonly AssessmentOption<Value>[];
};
