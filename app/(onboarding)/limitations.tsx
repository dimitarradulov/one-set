import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function LimitationsScreen() {
  return (
    <OnboardingStepScreen
      title="Limitations"
      description="Dummy assessment content for injury-sensitive or caution areas in training."
      nextHref="/training-direction"
      nextLabel="Next: Training Direction"
    />
  );
}
