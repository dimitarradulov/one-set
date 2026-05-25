import type { AssessmentDraftPersistedState } from '@/types/assessment-draft-store';

export const ASSESSMENT_DRAFT_STORAGE_KEY = 'one_set_assessment_draft';
export const ASSESSMENT_DRAFT_STORAGE_VERSION = 2;

export const INITIAL_PERSISTED_STATE: AssessmentDraftPersistedState = {
  mainGoal: null,
  trainingExperience: null,
  hitExperience: null,
  daysAvailablePerWeek: null,
  preferredSessionLength: null,
  equipmentAccess: null,
  recoveryProfile: null,
  lifestyleStress: null,
  limitations: [],
  trainingDirection: null,
  failureComfort: null,
};
