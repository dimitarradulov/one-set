import OnboardingStep from '@/components/OnboardingStep';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';

export default function ResultCalculationScreen() {
  const step = getPostAssessmentPreviewStep('result-calculation');

  return (
    <OnboardingStep
      title={step.title}
      description={step.description}
      nextHref={step.nextHref}
      nextLabel={step.nextLabel}
    />
  );
}
