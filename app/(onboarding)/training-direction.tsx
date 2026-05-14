import OnboardingStep from '@/components/OnboardingStep';

export default function TrainingDirectionScreen() {
  return (
    <OnboardingStep
      title="Training Direction"
      description="Dummy assessment content for selecting desired physique or performance direction."
      nextHref="/failure-comfort"
      nextLabel="Next: Failure Comfort"
    />
  );
}
