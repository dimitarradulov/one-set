import OnboardingStep from '@/components/OnboardingStep';

export default function FailureComfortScreen() {
  return (
    <OnboardingStep
      title="Failure Comfort"
      description="Dummy assessment content for comfort with pushing sets close to failure."
      nextHref="/result-calculation"
      nextLabel="Next: Result Calculation"
    />
  );
}
