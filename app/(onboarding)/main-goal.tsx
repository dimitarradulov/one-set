import OnboardingStep from '@/components/OnboardingStep';

export default function MainGoalScreen() {
  return (
    <OnboardingStep
      title="Main Goal"
      description="Dummy assessment content for selecting the user's primary training outcome."
      nextHref="/training-experience"
      nextLabel="Next: Training Experience"
    />
  );
}
