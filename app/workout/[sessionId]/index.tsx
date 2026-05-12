import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';
import { useLocalSearchParams } from 'expo-router';

export default function WorkoutOverviewScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();

  return (
    <PlaceholderScreen
      title="Workout Overview"
      description={`Session context: ${sessionId} — placeholder pre-workout overview content.`}>
      <PlaceholderLink href={`/workout/${sessionId}/exercise/1`}>Start Exercise 1</PlaceholderLink>
    </PlaceholderScreen>
  );
}
