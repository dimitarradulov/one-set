import OnboardingStep from '@/components/OnboardingStep';

export default function ResultCalculationScreen() {
  return (
    <OnboardingStep
      title="Result Calculation"
      description="Dummy assessment content for short analysis and starter program matching."
      nextHref="/recommended-program"
      nextLabel="Next: Recommended Program"
    />
  );
}
