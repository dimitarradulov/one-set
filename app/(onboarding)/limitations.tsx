import OnboardingStep from '@/components/OnboardingStep';

export default function LimitationsScreen() {
  return (
    <OnboardingStep
      title="Limitations"
      description="Dummy assessment content for injury-sensitive or caution areas in training."
      nextHref="/training-direction"
      nextLabel="Next: Training Direction"
    />
  );
}
