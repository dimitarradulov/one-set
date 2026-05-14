import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function FirstWorkoutPreviewScreen() {
  return (
    <OnboardingStepScreen
      title="First Workout Preview"
      description="Dummy onboarding wrap-up content previewing the first focused training session."
      nextHref="/program-intro"
      nextLabel="Continue to Program Intro"
    />
  );
}
