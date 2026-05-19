import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

export const MAIN_GOAL_IDS = [
  'build_muscle',
  'get_stronger',
  'recomp',
  'maintain_with_less_time',
  'return_after_break',
] as const;

export type MainGoalId = (typeof MAIN_GOAL_IDS)[number];

export const ASSESSMENT_DRAFT_STORAGE_KEY = 'one_set_assessment_draft';
export const ASSESSMENT_DRAFT_STORAGE_VERSION = 1;

interface AssessmentDraftPersistedState {
  mainGoal: MainGoalId | null;
}

export interface AssessmentDraftState extends AssessmentDraftPersistedState {
  isHydrated: boolean;
  setHydrated: (isHydrated: boolean) => void;
  commitMainGoal: (mainGoal: MainGoalId) => void;
}

const INITIAL_PERSISTED_STATE: AssessmentDraftPersistedState = {
  mainGoal: null,
};

export const createAssessmentDraftStore = () =>
  create<AssessmentDraftState>()(
    persist(
      (set) => ({
        ...INITIAL_PERSISTED_STATE,
        isHydrated: false,
        setHydrated: (isHydrated) => set({ isHydrated }),
        commitMainGoal: (mainGoal) => set({ mainGoal }),
      }),
      {
        name: ASSESSMENT_DRAFT_STORAGE_KEY,
        version: ASSESSMENT_DRAFT_STORAGE_VERSION,
        storage: createJSONStorage(() => AsyncStorage),
        partialize: (state) => ({ mainGoal: state.mainGoal }),
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
