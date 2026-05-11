import { Text, View } from 'react-native';

export default function Index() {
  return (
    <View className="flex-1 items-center justify-center gap-3 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">OneSet</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        NativeWind design tokens are active.
      </Text>
      <View className="h-14 w-full max-w-sm items-center justify-center rounded-2xl bg-brand-primary">
        <Text className="font-body-semibold text-body text-white">Start Workout</Text>
      </View>
    </View>
  );
}
