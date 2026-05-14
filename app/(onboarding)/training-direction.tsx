import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function TrainingDirectionScreen() {
  return (
    <OnboardingStepScreen
      title="Training Direction"
      description="Dummy assessment content for selecting desired physique or performance direction."
      nextHref="/failure-comfort"
      nextLabel="Next: Failure Comfort"
    />
  );
}
