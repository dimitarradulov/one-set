import { Link } from 'expo-router';
import { Image, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function OnboardingWelcomeScreen() {
  return (
    <SafeAreaView className="flex-1 bg-dark-background" edges={['top', 'bottom']}>
      <ScrollView
        className="flex-1"
        contentContainerStyle={{ flexGrow: 1 }}
        showsVerticalScrollIndicator={false}>
        <View className="flex-1 justify-between px-6 py-5">
          <View className="flex-1 items-center justify-center">
            <View className="mb-8 rounded-3xl border border-dark-border bg-dark-surface p-5">
              <Image
                accessibilityLabel="OneSet logo"
                className="h-16 w-16"
                resizeMode="contain"
                source={require('../../assets/splash-icon-light.png')}
              />
            </View>
            <Text className="max-w-[320px] text-center font-display text-display text-dark-text-primary">
              Build muscle with fewer, harder, smarter workouts.
            </Text>
            <Text className="mt-4 max-w-[330px] text-center font-body text-body-lg text-dark-text-secondary">
              OneSet creates HIT-based training programs built around your experience, recovery,
              schedule, and equipment.
            </Text>
          </View>

          <View className="gap-3 pb-2">
            <Link
              className="min-h-[56px] items-center justify-center rounded-2xl bg-brand-primary px-5 py-4 text-center font-body-semibold text-body text-white"
              href="/main-goal">
              Start Assessment
            </Link>
            <Text className="text-center font-body text-body-sm text-dark-text-secondary">
              Takes less than 2 minutes
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
