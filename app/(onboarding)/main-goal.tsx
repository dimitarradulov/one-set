import { OnboardingStepScreen } from './OnboardingStepScreen';

export default function MainGoalScreen() {
  return (
    <OnboardingStepScreen
      title="Main Goal"
      description="Dummy assessment content for selecting the user's primary training outcome."
      nextHref="/training-experience"
      nextLabel="Next: Training Experience"
    />
  );
}
