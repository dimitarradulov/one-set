import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function HitExperienceScreen() {
  return (
    <OnboardingStepScreen
      title="HIT Experience"
      description="Dummy assessment content for familiarity with high-intensity training methods."
      nextHref="/days-available"
      nextLabel="Next: Days Available"
    />
  );
}
