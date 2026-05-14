import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function OnboardingWelcomeScreen() {
  return (
    <OnboardingStepScreen
      title="Welcome"
      description="Dummy welcome content introducing the coach-style onboarding assessment."
      nextHref="/main-goal"
      nextLabel="Start Assessment"
    />
  );
}
