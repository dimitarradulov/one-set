import OnboardingStep from '@/components/OnboardingStep';

export default function DaysAvailableScreen() {
  return (
    <OnboardingStep
      title="Days Available"
      description="Dummy assessment content for realistic weekly training availability."
      nextHref="/session-length"
      nextLabel="Next: Session Length"
    />
  );
}
