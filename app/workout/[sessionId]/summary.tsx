import { Link, useLocalSearchParams } from 'expo-router';
import { Text, View } from 'react-native';

export default function WorkoutSummaryScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();

  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Workout Summary</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Session context: {sessionId}
      </Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Placeholder post-workout summary screen.
      </Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href="/(tabs)">
        Back to Home
      </Link>
      <Link
        className="rounded-2xl border border-brand-primary px-5 py-3 font-body-semibold text-body text-brand-primary"
        href="/(tabs)/logbook">
        Back to Logbook
      </Link>
    </View>
  );
}
