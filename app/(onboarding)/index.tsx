import { Link } from 'expo-router';
import { Text, View } from 'react-native';

export default function AccessLegalGateScreen() {
  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Access and Legal Gate</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Placeholder gate sequence before workout preview.
      </Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href="/program-intro">
        Continue to Program Preview
      </Link>
    </View>
  );
}
