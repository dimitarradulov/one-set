import { Link, useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export default function ActiveExerciseScreen() {
  const { sessionId, exerciseId } = useLocalSearchParams<{
    sessionId: string;
    exerciseId: string;
  }>();

  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Active Exercise</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Session: {sessionId} • Exercise: {exerciseId}
      </Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Placeholder one-exercise-at-a-time logging screen.
      </Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href={`/workout/${sessionId}/rest/${exerciseId}`}>
        Complete Set and Start Rest
      </Link>
    </View>
  );
}
