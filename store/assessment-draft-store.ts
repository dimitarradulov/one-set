import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import {
  ASSESSMENT_DRAFT_STORAGE_KEY,
  ASSESSMENT_DRAFT_STORAGE_VERSION,
  INITIAL_PERSISTED_STATE,
} from '@/constants/assessment-draft-store';
import type {
  AssessmentDraftPersistedState,
  AssessmentDraftState,
} from '@/types/assessment-draft-store';

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
