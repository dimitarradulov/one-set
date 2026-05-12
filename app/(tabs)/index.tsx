import { Link } from 'expo-router';
import { Text, View } from 'react-native';

export default function HomeScreen() {
  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Home</Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href="/program-intro">
        Open Workout Preview
      </Link>
    </View>
  );
}
