import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function ResultCalculationScreen() {
  return (
    <OnboardingStepScreen
      title="Result Calculation"
      description="Dummy assessment content for short analysis and starter program matching."
      nextHref="/recommended-program"
      nextLabel="Next: Recommended Program"
    />
  );
}
