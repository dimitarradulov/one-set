import OnboardingStep from '@/components/OnboardingStep';

export default function HitExperienceScreen() {
  return (
    <OnboardingStep
      title="HIT Experience"
      description="Dummy assessment content for familiarity with high-intensity training methods."
      nextHref="/days-available"
      nextLabel="Next: Days Available"
    />
  );
}
