import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { useLocalSearchParams } from 'expo-router';

export default function WorkoutSummaryScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();

  return (
    <PlaceholderScreen
      title="Workout Summary"
      description={`Session context: ${sessionId} — placeholder post-workout summary.`}>
      <PlaceholderLink href="/(tabs)">Back to Home</PlaceholderLink>
      <PlaceholderLink href="/(tabs)/logbook" variant="secondary">
        Back to Logbook
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
