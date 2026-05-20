import OnboardingStep from '@/components/OnboardingStep';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';

export default function RecommendedProgramScreen() {
  const step = getPostAssessmentPreviewStep('recommended-program');

  return (
    <OnboardingStep
      title={step.title}
      description={step.description}
      nextHref={step.nextHref}
      nextLabel={step.nextLabel}
    />
  );
}
