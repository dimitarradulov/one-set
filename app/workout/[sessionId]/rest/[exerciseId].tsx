import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { useLocalSearchParams } from 'expo-router';

export default function RestTimerScreen() {
  const { sessionId, exerciseId } = useLocalSearchParams<{
    sessionId: string;
    exerciseId: string;
  }>();
  const nextExerciseId = Number(exerciseId) + 1;

  return (
    <PlaceholderScreen
      title="Rest Timer"
      description={`Session: ${sessionId} • Rest after exercise: ${exerciseId} — placeholder rest step.`}>
      <PlaceholderLink href={`/workout/${sessionId}/exercise/${nextExerciseId}`}>
        Continue to Exercise {nextExerciseId}
      </PlaceholderLink>
      <PlaceholderLink href={`/workout/${sessionId}/summary`} variant="secondary">
        Finish Workout
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
