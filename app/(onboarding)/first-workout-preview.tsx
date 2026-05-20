import OnboardingStep from '@/components/OnboardingStep';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';

export default function FirstWorkoutPreviewScreen() {
  const step = getPostAssessmentPreviewStep('first-workout-preview');

  return (
    <OnboardingStep
      title={step.title}
      description={step.description}
      nextHref={step.nextHref}
      nextLabel={step.nextLabel}
    />
  );
}
