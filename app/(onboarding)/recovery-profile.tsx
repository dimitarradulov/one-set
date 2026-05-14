import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function RecoveryProfileScreen() {
  return (
    <OnboardingStepScreen
      title="Recovery Profile"
      description="Dummy assessment content for how quickly the user recovers from hard training."
      nextHref="/lifestyle-stress"
      nextLabel="Next: Lifestyle Stress"
    />
  );
}
