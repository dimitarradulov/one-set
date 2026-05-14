import OnboardingStep from '@/components/OnboardingStep';

export default function OnboardingWelcomeScreen() {
  return (
    <OnboardingStep
      title="Welcome"
      description="Dummy welcome content introducing the coach-style onboarding assessment."
      nextHref="/main-goal"
      nextLabel="Start Assessment"
    />
  );
}
