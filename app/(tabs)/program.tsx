import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function ProgramPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Program"
      description="Dummy Program content for current plan context and what is coming next.">
      <PlaceholderLink href="/workout/session-a">Route Test: Workout Preview</PlaceholderLink>
      <PlaceholderLink href="/workout/session-a/exercise/1" variant="secondary">
        Route Test: Exercise Detail
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
