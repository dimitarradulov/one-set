import { Stack, useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { BackHandler, Text, View } from 'react-native';

import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import { useAssessmentDraftStore } from '@/store/assessment-draft-store';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';
import {
  getResultCalculationTransitionState,
  RESULT_CALCULATION_MESSAGES,
  RESULT_CALCULATION_MESSAGE_DURATION_MS,
} from '@/utils/result-calculation-transition';

export default function ResultCalculationScreen() {
  const router = useRouter();
  const step = getPostAssessmentPreviewStep('result-calculation');

  const isHydrated = useAssessmentDraftStore((state) => state.isHydrated);
  const mainGoal = useAssessmentDraftStore((state) => state.mainGoal);
  const trainingExperience = useAssessmentDraftStore((state) => state.trainingExperience);
  const hitExperience = useAssessmentDraftStore((state) => state.hitExperience);
  const daysAvailablePerWeek = useAssessmentDraftStore((state) => state.daysAvailablePerWeek);
  const preferredSessionLength = useAssessmentDraftStore((state) => state.preferredSessionLength);
  const equipmentAccess = useAssessmentDraftStore((state) => state.equipmentAccess);
  const recoveryProfile = useAssessmentDraftStore((state) => state.recoveryProfile);
  const lifestyleStress = useAssessmentDraftStore((state) => state.lifestyleStress);
  const limitations = useAssessmentDraftStore((state) => state.limitations);
  const trainingDirection = useAssessmentDraftStore((state) => state.trainingDirection);
  const failureComfort = useAssessmentDraftStore((state) => state.failureComfort);

  const preparedState = usePostAssessmentPreviewStore((state) => state.preparedState);
  const prepareRecommendation = usePostAssessmentPreviewStore(
    (state) => state.prepareRecommendation
  );

  const [elapsedMs, setElapsedMs] = useState(0);

  useEffect(() => {
    const subscription = BackHandler.addEventListener('hardwareBackPress', () => true);

    return () => {
      subscription.remove();
    };
  }, []);

  useEffect(() => {
    if (!isHydrated) {
      return;
    }

    prepareRecommendation({
      mainGoal,
      trainingExperience,
      hitExperience,
      daysAvailablePerWeek,
      preferredSessionLength,
      equipmentAccess,
      recoveryProfile,
      lifestyleStress,
      limitations,
      trainingDirection,
      failureComfort,
    });
  }, [
    daysAvailablePerWeek,
    equipmentAccess,
    failureComfort,
    hitExperience,
    isHydrated,
    lifestyleStress,
    limitations,
    mainGoal,
    preferredSessionLength,
    prepareRecommendation,
    recoveryProfile,
    trainingDirection,
    trainingExperience,
  ]);

  useEffect(() => {
    if (!isHydrated) {
      return;
    }

    setElapsedMs(0);

    const timeoutIds = RESULT_CALCULATION_MESSAGES.map((_, index) => {
      const delay = (index + 1) * RESULT_CALCULATION_MESSAGE_DURATION_MS;

      return setTimeout(() => {
        setElapsedMs(delay);
      }, delay);
    });

    return () => {
      timeoutIds.forEach((timeoutId) => {
        clearTimeout(timeoutId);
      });
    };
  }, [isHydrated]);

  const transitionState = useMemo(
    () => getResultCalculationTransitionState(elapsedMs, preparedState),
    [elapsedMs, preparedState]
  );

  useEffect(() => {
    if (!transitionState.canAutoAdvance) {
      return;
    }

    router.replace('/recommended-program');
  }, [router, transitionState.canAutoAdvance]);

  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Stack.Screen options={{ gestureEnabled: false }} />
      <Text className="text-center font-display text-h1 text-dark-text-primary">{step.title}</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        {step.description}
      </Text>
      <Text className="text-center font-body text-lg text-dark-text-primary">
        {transitionState.activeMessage}
      </Text>
    </View>
  );
}
