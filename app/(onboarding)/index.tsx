import { Link } from 'expo-router';
import { Image, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { welcomeContent } from './welcome-content';

export default function OnboardingWelcomeScreen() {
  return (
    <SafeAreaView className="flex-1 bg-dark-background" edges={['top', 'bottom']}>
      <ScrollView
        className="flex-1"
        contentContainerStyle={{ flexGrow: 1 }}
        showsVerticalScrollIndicator={false}>
        <View className="flex-1 justify-between px-6 py-5">
          <View className="items-center gap-8 pt-4">
            <View className="rounded-3xl border border-dark-border bg-dark-surface p-5">
              <Image
                accessibilityLabel="OneSet logo"
                className="h-16 w-16"
                resizeMode="contain"
                source={require('../../assets/splash-icon-light.png')}
              />
            </View>
            <Text className="max-w-[320px] text-center font-display text-display text-dark-text-primary">
              {welcomeContent.headline}
            </Text>
          </View>

          <View className="gap-3 pb-2">
            <Link
              className="min-h-[56px] items-center justify-center rounded-2xl bg-brand-primary px-5 py-4 text-center font-body-semibold text-body text-white"
              href={welcomeContent.cta.href}>
              {welcomeContent.cta.label}
            </Link>
            <Link
              className="self-center px-4 py-4 text-center font-body text-body-sm text-dark-text-secondary"
              href={welcomeContent.signIn.href}>
              {welcomeContent.signIn.label}
            </Link>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
