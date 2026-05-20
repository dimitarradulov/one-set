import OnboardingStep from '@/components/OnboardingStep';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';

export default function HitPrinciplesScreen() {
  const step = getPostAssessmentPreviewStep('hit-principles');

  return (
    <OnboardingStep
      title={step.title}
      description={step.description}
      nextHref={step.nextHref}
      nextLabel={step.nextLabel}
    />
  );
}
