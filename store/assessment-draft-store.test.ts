jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
);

import AsyncStorage from '@react-native-async-storage/async-storage';

import {
  ASSESSMENT_DRAFT_STORAGE_KEY,
  ASSESSMENT_DRAFT_STORAGE_VERSION,
  createAssessmentDraftStore,
  type MainGoalId,
} from './assessment-draft-store';

const seedPersistedMainGoal = async (mainGoal: MainGoalId) => {
  await AsyncStorage.setItem(
    ASSESSMENT_DRAFT_STORAGE_KEY,
    JSON.stringify({
      state: { mainGoal },
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

  test('persists the committed value under the stable key and version', async () => {
    const store = createAssessmentDraftStore();
    await store.persist.rehydrate();

    store.getState().commitMainGoal('recomp');

    const serializedState = await AsyncStorage.getItem(ASSESSMENT_DRAFT_STORAGE_KEY);
    expect(serializedState).toBeTruthy();

    const persisted = JSON.parse(serializedState as string) as {
      state: { mainGoal: MainGoalId };
      version: number;
    };

    expect(persisted.state.mainGoal).toBe('recomp');
    expect(persisted.version).toBe(ASSESSMENT_DRAFT_STORAGE_VERSION);
  });
});
