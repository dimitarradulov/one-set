import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { useLocalSearchParams } from 'expo-router';

export default function WorkoutOverviewScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();

  return (
    <PlaceholderScreen
      title="Workout Overview"
      description={`Session context: ${sessionId} — placeholder pre-workout overview content.`}>
      <PlaceholderLink href={`/workout/${sessionId}/exercise/1`}>Start Exercise 1</PlaceholderLink>
      <PlaceholderLink href="/(tabs)/program" variant="secondary">
        Route Test: Back to Program
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
