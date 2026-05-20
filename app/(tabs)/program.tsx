import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getPreviewExerciseHref, getPreviewWorkoutHref } from '@/utils/workout-session-flow';

export default function ProgramPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Program"
      description="Dummy Program content for current plan context and what is coming next.">
      <PlaceholderLink href={getPreviewWorkoutHref()}>Route Test: Workout Preview</PlaceholderLink>
      <PlaceholderLink href={getPreviewExerciseHref()} variant="secondary">
        Route Test: Exercise Detail
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
