import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import type {
  AssessmentDraftAnswerKey,
  AssessmentDraftAnswers,
  FailureComfortId,
  LimitationId,
  MainGoalId,
} from '@/constants/assessment-intake';

export const ASSESSMENT_DRAFT_STORAGE_KEY = 'one_set_assessment_draft';
export const ASSESSMENT_DRAFT_STORAGE_VERSION = 2;

type AssessmentDraftPersistedState = AssessmentDraftAnswers;

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

const INITIAL_PERSISTED_STATE: AssessmentDraftPersistedState = {
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

const persistedAnswers = (state: AssessmentDraftState): AssessmentDraftPersistedState => ({
  mainGoal: state.mainGoal,
  trainingExperience: state.trainingExperience,
  hitExperience: state.hitExperience,
  daysAvailablePerWeek: state.daysAvailablePerWeek,
  preferredSessionLength: state.preferredSessionLength,
  equipmentAccess: state.equipmentAccess,
  recoveryProfile: state.recoveryProfile,
  lifestyleStress: state.lifestyleStress,
  limitations: state.limitations,
  trainingDirection: state.trainingDirection,
  failureComfort: state.failureComfort,
});

export const createAssessmentDraftStore = () =>
  create<AssessmentDraftState>()(
    persist(
      (set) => ({
        ...INITIAL_PERSISTED_STATE,
        isHydrated: false,
        setHydrated: (isHydrated) => set({ isHydrated }),
        commitMainGoal: (mainGoal) => set({ mainGoal }),
        commitLimitations: (limitations) => set({ limitations }),
        commitFailureComfort: (failureComfort) => set({ failureComfort }),
        commitAnswer: (answerKey, answer) => set({ [answerKey]: answer }),
      }),
      {
        name: ASSESSMENT_DRAFT_STORAGE_KEY,
        version: ASSESSMENT_DRAFT_STORAGE_VERSION,
        storage: createJSONStorage(() => AsyncStorage),
        partialize: persistedAnswers,
        onRehydrateStorage: () => (state, error) => {
          if (error) {
            console.warn('Failed to hydrate assessment draft store', error);
          }

          state?.setHydrated(true);
        },
      }
    )
  );

export const useAssessmentDraftStore = createAssessmentDraftStore();
