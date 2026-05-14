import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function SessionLengthScreen() {
  return (
    <OnboardingStepScreen
      title="Session Length"
      description="Dummy assessment content for preferred workout duration per session."
      nextHref="/equipment-access"
      nextLabel="Next: Equipment Access"
    />
  );
}
