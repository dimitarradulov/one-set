import { Link, useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export default function RestTimerScreen() {
  const { sessionId, exerciseId } = useLocalSearchParams<{
    sessionId: string;
    exerciseId: string;
  }>();
  const nextExerciseId = Number(exerciseId) + 1;

  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Rest Timer</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Session: {sessionId} • Rest after exercise: {exerciseId}
      </Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Placeholder rest-timer step before moving to next exercise or finish.
      </Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href={`/workout/${sessionId}/exercise/${nextExerciseId}`}>
        Continue to Exercise {nextExerciseId}
      </Link>
      <Link
        className="rounded-2xl border border-brand-primary px-5 py-3 font-body-semibold text-body text-brand-primary"
        href={`/workout/${sessionId}/summary`}>
        Finish Workout
      </Link>
    </View>
  );
}
