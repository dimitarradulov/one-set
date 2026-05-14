import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function LogbookPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Logbook"
      description="Dummy Logbook content for workout and exercise progress history.">
      <PlaceholderLink href="/workout/session-a/summary">
        Route Test: Workout Session Detail
      </PlaceholderLink>
      <PlaceholderLink href="/logbook/exercise/leg-press" variant="secondary">
        Route Test: Exercise History
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
