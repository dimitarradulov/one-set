import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';
import { useLocalSearchParams } from 'expo-router';

export default function ActiveExerciseScreen() {
  const { sessionId, exerciseId } = useLocalSearchParams<{
    sessionId: string;
    exerciseId: string;
  }>();

  return (
    <PlaceholderScreen
      title="Active Exercise"
      description={`Session: ${sessionId} • Exercise: ${exerciseId} — placeholder one-exercise-at-a-time logging.`}>
      <PlaceholderLink href={`/workout/${sessionId}/rest/${exerciseId}`}>
        Complete Set and Start Rest
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
