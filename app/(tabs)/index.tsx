import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getPreviewWorkoutHref } from '@/utils/workout-session-flow';

export default function HomePlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Home"
      description="Dummy Home content for the MVP command center answering: What should I do next?">
      <PlaceholderLink href="/program-intro">Route Test: Start Workout Path</PlaceholderLink>
      <PlaceholderLink href={getPreviewWorkoutHref()} variant="secondary">
        Route Test: Open Next Workout
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
