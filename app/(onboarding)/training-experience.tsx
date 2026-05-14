import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function TrainingExperienceScreen() {
  return (
    <OnboardingStepScreen
      title="Training Experience"
      description="Dummy assessment content for current lifting consistency and experience level."
      nextHref="/hit-experience"
      nextLabel="Next: HIT Experience"
    />
  );
}
