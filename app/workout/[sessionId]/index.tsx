import { Link, useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export default function WorkoutOverviewScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();

  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Workout Overview</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Session context: {sessionId}
      </Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Placeholder pre-workout overview content.
      </Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href={`/workout/${sessionId}/exercise/1`}>
        Start Exercise 1
      </Link>
    </View>
  );
}
