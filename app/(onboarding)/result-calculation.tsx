import { Stack, useRouter, type Href } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { ASSESSMENT_INTAKE_QUESTIONS } from '@/constants/assessment-intake';
import {
  INITIAL_MESSAGE_SEQUENCE_STATE,
  RESULT_CALCULATION_SCREEN_OPTIONS,
} from '@/constants/result-calculation-screen';
import {
  RESULT_CALCULATION_MESSAGES,
  RESULT_CALCULATION_MESSAGE_DURATION_MS,
  RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS,
} from '@/constants/result-calculation-transition';
import { useAssessmentDraftStore } from '@/store/assessment-draft-store';
import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import type { AssessmentDraftAnswers } from '@/types/assessment';
import type { PostAssessmentPreviewState } from '@/types/post-assessment-preview';
import type { MessageSequenceState } from '@/types/result-calculation-screen';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';

const getAssessmentDraftAnswers = (): AssessmentDraftAnswers => {
  const state = useAssessmentDraftStore.getState();

  return {
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
  };
};

const getIncompleteAssessmentRoute = (preparedState: PostAssessmentPreviewState): Href => {
  if (preparedState.status !== 'incomplete') {
    return '/main-goal';
  }

  const firstMissingAnswerKey = preparedState.missingAnswerKeys[0];
  const question = ASSESSMENT_INTAKE_QUESTIONS.find(
    (item) => item.answerKey === firstMissingAnswerKey
  );

  return question?.route ?? '/main-goal';
};

export default function ResultCalculationScreen() {
  const step = getPostAssessmentPreviewStep('result-calculation');
  const { replace } = useRouter();

  const isHydrated = useAssessmentDraftStore((state) => state.isHydrated);
  const preparedState = usePostAssessmentPreviewStore((state) => state.preparedState);
  const prepareRecommendation = usePostAssessmentPreviewStore(
    (state) => state.prepareRecommendation
  );

  const [messageSequenceState, setMessageSequenceState] = useState<MessageSequenceState>(
    INITIAL_MESSAGE_SEQUENCE_STATE
  );

  useEffect(() => {
    if (!isHydrated) {
      return;
    }

    prepareRecommendation(getAssessmentDraftAnswers());
  }, [isHydrated, prepareRecommendation]);

  useEffect(() => {
    if (!isHydrated) {
      return;
    }

    setMessageSequenceState(INITIAL_MESSAGE_SEQUENCE_STATE);

    const messageTimeoutIds = RESULT_CALCULATION_MESSAGES.slice(1).map((_, index) => {
      const activeMessageIndex = index + 1;
      const delay = activeMessageIndex * RESULT_CALCULATION_MESSAGE_DURATION_MS;

      return setTimeout(() => {
        setMessageSequenceState({
          activeMessageIndex,
          hasCompleted: false,
        });
      }, delay);
    });

    const completionTimeoutId = setTimeout(() => {
      setMessageSequenceState((currentState) => ({
        ...currentState,
        hasCompleted: true,
      }));
    }, RESULT_CALCULATION_MIN_VISIBLE_DURATION_MS);

    return () => {
      messageTimeoutIds.forEach((timeoutId) => {
        clearTimeout(timeoutId);
      });
      clearTimeout(completionTimeoutId);
    };
  }, [isHydrated]);

  const activeMessage = RESULT_CALCULATION_MESSAGES[messageSequenceState.activeMessageIndex];
  const hasIncompleteAssessment =
    messageSequenceState.hasCompleted && preparedState?.status === 'incomplete';
  const canAutoAdvance = messageSequenceState.hasCompleted && preparedState?.status === 'ready';

  useEffect(() => {
    if (!canAutoAdvance) {
      return;
    }

    replace('/recommended-program');
  }, [canAutoAdvance, replace]);

  const handleReturnToAssessment = () => {
    if (!preparedState) {
      replace('/main-goal');
      return;
    }

    replace(getIncompleteAssessmentRoute(preparedState));
  };

  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Stack.Screen options={RESULT_CALCULATION_SCREEN_OPTIONS} />
      <Text className="text-center font-display text-h1 text-dark-text-primary">{step.title}</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        {step.description}
      </Text>
      <Text className="text-center font-body text-lg text-dark-text-primary">
        {hasIncompleteAssessment ? 'Assessment incomplete.' : activeMessage}
      </Text>
      {hasIncompleteAssessment ? (
        <>
          <Text className="text-center font-body text-body text-dark-text-secondary">
            OneSet needs every assessment answer before it can build your starter program.
          </Text>
          <Pressable
            accessibilityRole="button"
            className="items-center rounded-2xl bg-brand-primary px-5 py-3"
            onPress={handleReturnToAssessment}>
            <Text className="text-center font-body-semibold text-body text-white">
              Return to assessment
            </Text>
          </Pressable>
        </>
      ) : null}
    </View>
  );
}
