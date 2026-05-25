import AsyncStorage from '@react-native-async-storage/async-storage';

import {
  ASSESSMENT_DRAFT_STORAGE_KEY,
  ASSESSMENT_DRAFT_STORAGE_VERSION,
} from '@/constants/assessment-draft-store';
import type { MainGoalId } from '@/types/assessment';
import type { AssessmentDraftPersistedState } from '@/types/assessment-draft-store';

import { createAssessmentDraftStore } from '../assessment-draft-store';

jest.mock('@react-native-async-storage/async-storage', () =>
  jest.requireActual('@react-native-async-storage/async-storage/jest/async-storage-mock')
);

const seedPersistedMainGoal = async (mainGoal: MainGoalId) => {
  await AsyncStorage.setItem(
    ASSESSMENT_DRAFT_STORAGE_KEY,
    JSON.stringify({
      state: { mainGoal },
      version: ASSESSMENT_DRAFT_STORAGE_VERSION,
    })
  );
};

const seedPersistedDraftState = async (state: AssessmentDraftPersistedState) => {
  await AsyncStorage.setItem(
    ASSESSMENT_DRAFT_STORAGE_KEY,
    JSON.stringify({
      state,
      version: ASSESSMENT_DRAFT_STORAGE_VERSION,
    })
  );
};

describe('createAssessmentDraftStore', () => {
  beforeEach(async () => {
    await AsyncStorage.clear();
    jest.clearAllMocks();
  });

  test('commits and replaces a previously committed main goal value', async () => {
    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    store.getState().commitMainGoal('build_muscle');
    expect(store.getState().mainGoal).toBe('build_muscle');

    store.getState().commitMainGoal('get_stronger');
    expect(store.getState().mainGoal).toBe('get_stronger');
  });

  test('commits explicit Assessment Draft fields through typed answer keys', async () => {
    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    store.getState().commitAnswer('trainingExperience', '1_to_3_years');
    store.getState().commitAnswer('limitations', ['shoulders', 'wrists']);
    store.getState().commitAnswer('failureComfort', 'comfortable_to_failure');

    expect(store.getState().trainingExperience).toBe('1_to_3_years');
    expect(store.getState().limitations).toEqual(['shoulders', 'wrists']);
    expect(store.getState().failureComfort).toBe('comfortable_to_failure');
  });

  test('replaces a committed answer when committing the same key again', async () => {
    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    store.getState().commitAnswer('trainingExperience', 'less_than_1_year');
    expect(store.getState().trainingExperience).toBe('less_than_1_year');

    store.getState().commitAnswer('trainingExperience', '3_to_5_years');
    expect(store.getState().trainingExperience).toBe('3_to_5_years');
  });

  test('exposes hydration state for interaction gating', async () => {
    const store = createAssessmentDraftStore();

    expect(store.getState().isHydrated).toBe(false);

    await store.persist.rehydrate();

    expect(store.getState().isHydrated).toBe(true);
  });

  test('rehydrates a committed main goal from persisted storage', async () => {
    await seedPersistedMainGoal('return_after_break');

    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    expect(store.getState().mainGoal).toBe('return_after_break');
    expect(store.getState().isHydrated).toBe(true);
  });

  test('rehydrates persisted Assessment Draft answers across question keys', async () => {
    await seedPersistedDraftState({
      mainGoal: 'get_stronger',
      trainingExperience: '1_to_3_years',
      hitExperience: 'tried_before',
      daysAvailablePerWeek: '3',
      preferredSessionLength: '45',
      equipmentAccess: 'basic_gym',
      recoveryProfile: 'average',
      lifestyleStress: 'moderate',
      limitations: ['wrists'],
      trainingDirection: 'classic_balanced',
      failureComfort: 'push_hard_not_every_set',
    });

    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    expect(store.getState()).toMatchObject({
      mainGoal: 'get_stronger',
      trainingExperience: '1_to_3_years',
      hitExperience: 'tried_before',
      daysAvailablePerWeek: '3',
      preferredSessionLength: '45',
      equipmentAccess: 'basic_gym',
      recoveryProfile: 'average',
      lifestyleStress: 'moderate',
      limitations: ['wrists'],
      trainingDirection: 'classic_balanced',
      failureComfort: 'push_hard_not_every_set',
      isHydrated: true,
    });
  });

  test('persists the committed value under the stable key and version', async () => {
    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    store.getState().commitMainGoal('recomp');

    const serializedState = await AsyncStorage.getItem(ASSESSMENT_DRAFT_STORAGE_KEY);
    expect(serializedState).toBeTruthy();

    const persisted = JSON.parse(serializedState as string) as {
      state: {
        mainGoal: MainGoalId;
        limitations: string[];
      };
      version: number;
    };

    expect(persisted.state.mainGoal).toBe('recomp');
    expect(persisted.state.limitations).toEqual([]);
    expect(persisted.version).toBe(ASSESSMENT_DRAFT_STORAGE_VERSION);
  });
});
