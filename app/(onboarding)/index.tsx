import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Link } from 'expo-router';
import { Image, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { welcomeContent, type WelcomeBenefit } from './welcome-content';

function WelcomeBenefitRow({ description, icon, title }: WelcomeBenefit) {
  return (
    <View className="flex-row items-start gap-3 rounded-2xl border border-dark-border bg-dark-surface px-4 py-4">
      <View className="h-11 w-11 items-center justify-center rounded-2xl bg-brand-primary-soft">
        <MaterialCommunityIcons color="#A78BFA" name={icon} size={22} />
      </View>
      <View className="flex-1 gap-1">
        <Text className="font-body-semibold text-body text-dark-text-primary">{title}</Text>
        <Text className="font-body text-body-sm text-dark-text-secondary">{description}</Text>
      </View>
    </View>
  );
}

export default function OnboardingWelcomeScreen() {
  return (
    <SafeAreaView className="flex-1 bg-dark-background" edges={['top', 'bottom']}>
      <ScrollView
        className="flex-1"
        contentContainerStyle={{ flexGrow: 1 }}
        showsVerticalScrollIndicator={false}>
        <View className="flex-1 justify-between px-6 py-5">
          <View className="gap-8 pt-4">
            <View className="items-center">
              <View className="mb-8 rounded-3xl border border-dark-border bg-dark-surface p-5">
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
              <Text className="mt-4 max-w-[330px] text-center font-body text-body-lg text-dark-text-secondary">
                {welcomeContent.subtext}
              </Text>
            </View>

            <View className="gap-3">
              {welcomeContent.benefits.map((benefit) => (
                <WelcomeBenefitRow key={benefit.title} {...benefit} />
              ))}
            </View>
          </View>

          <View className="gap-3 pb-2">
            <Link
              className="min-h-[56px] items-center justify-center rounded-2xl bg-brand-primary px-5 py-4 text-center font-body-semibold text-body text-white"
              href={welcomeContent.cta.href}>
              {welcomeContent.cta.label}
            </Link>
            <Text className="text-center font-body text-body-sm text-dark-text-secondary">
              {welcomeContent.helperText}
            </Text>
            <Link
              className="self-center px-4 py-4 text-center font-body text-body-sm text-dark-text-secondary"
              href={welcomeContent.footer.href}>
              {welcomeContent.footer.prompt}{' '}
              <Text className="font-body-semibold text-brand-primary">
                {welcomeContent.footer.actionLabel}
              </Text>
            </Link>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
