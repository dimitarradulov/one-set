import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function DaysAvailableScreen() {
  return (
    <OnboardingStepScreen
      title="Days Available"
      description="Dummy assessment content for realistic weekly training availability."
      nextHref="/session-length"
      nextLabel="Next: Session Length"
    />
  );
}
