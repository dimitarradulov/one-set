import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function FailureComfortScreen() {
  return (
    <OnboardingStepScreen
      title="Failure Comfort"
      description="Dummy assessment content for comfort with pushing sets close to failure."
      nextHref="/result-calculation"
      nextLabel="Next: Result Calculation"
    />
  );
}
