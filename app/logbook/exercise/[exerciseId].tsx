import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { useLocalSearchParams } from 'expo-router';

export default function ExerciseHistoryDetailScreen() {
  const { exerciseId } = useLocalSearchParams<{ exerciseId: string }>();

  return (
    <PlaceholderScreen
      title="Exercise History Detail"
      description={`Exercise context: ${exerciseId} — placeholder history detail from the logbook.`}>
      <PlaceholderLink href="/(tabs)/logbook">Route Test: Back to Logbook</PlaceholderLink>
      <PlaceholderLink href="/workout/session-a/summary" variant="secondary">
        Route Test: Open Workout Session Detail
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
