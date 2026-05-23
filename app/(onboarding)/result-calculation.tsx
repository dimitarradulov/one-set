import { useEffect } from 'react';

import OnboardingStep from '@/components/OnboardingStep';
import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import { useAssessmentDraftStore } from '@/store/assessment-draft-store';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';

export default function ResultCalculationScreen() {
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
  const prepareRecommendation = usePostAssessmentPreviewStore(
    (state) => state.prepareRecommendation
  );

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

  return (
    <OnboardingStep
      title={step.title}
      description={step.description}
      nextHref={step.nextHref}
      nextLabel={step.nextLabel}
    />
  );
}
