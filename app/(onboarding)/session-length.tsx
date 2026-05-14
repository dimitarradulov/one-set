import OnboardingStep from '@/components/OnboardingStep';

export default function SessionLengthScreen() {
  return (
    <OnboardingStep
      title="Session Length"
      description="Dummy assessment content for preferred workout duration per session."
      nextHref="/equipment-access"
      nextLabel="Next: Equipment Access"
    />
  );
}
