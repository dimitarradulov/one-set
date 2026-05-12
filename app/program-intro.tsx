import { Link } from 'expo-router';
import { Text, View } from 'react-native';

const previewSessionId = 'session-a';

export default function ProgramIntroScreen() {
  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="font-display text-h1 text-dark-text-primary">Program Intro</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        Workout preview placeholder with entry into the focused workout flow.
      </Text>
      <Link
        className="rounded-2xl bg-brand-primary px-5 py-3 font-body-semibold text-body text-white"
        href={`/workout/${previewSessionId}`}>
        Start Focused Session Preview
      </Link>
    </View>
  );
}
