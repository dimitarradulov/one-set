import type { Href } from 'expo-router';
import { Link } from 'expo-router';
import { Image, ScrollView, Text, useWindowDimensions, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

type WelcomeHeroAction = {
  label: string;
  href: Href;
};

type WelcomeHeroProps = {
  headline: string;
  cta: WelcomeHeroAction;
  signIn: WelcomeHeroAction;
};

const HERO_HEIGHT_RATIO = 0.68;
const HERO_MIN_HEIGHT = 360;
const HERO_MAX_HEIGHT = 620;

export default function WelcomeHero({ cta, headline, signIn }: WelcomeHeroProps) {
  const { height } = useWindowDimensions();
  const heroHeight = Math.max(
    HERO_MIN_HEIGHT,
    Math.min(HERO_MAX_HEIGHT, Math.round(height * HERO_HEIGHT_RATIO))
  );

  return (
    <SafeAreaView className="flex-1 bg-dark-background" edges={['top', 'bottom']}>
      <View className="flex-1 bg-dark-background">
        <View className="absolute inset-x-0 top-0 overflow-hidden" style={{ height: heroHeight }}>
          <Image
            accessibilityLabel="Onboarding hero image"
            className="h-full w-full"
            resizeMode="cover"
            source={require('../assets/onboarding.png')}
            style={{ transform: [{ scale: 1.12 }, { translateY: -28 }] }}
          />
          <View className="absolute inset-0 bg-black/25" />
          <View className="absolute inset-x-0 bottom-0 h-36 bg-dark-background/55" />
          <View className="absolute inset-x-0 bottom-0 h-28 bg-dark-background/70" />
          <View className="absolute inset-x-0 bottom-0 h-20 bg-dark-background/85" />
          <View className="absolute inset-x-0 bottom-0 h-14 bg-dark-background" />
        </View>

        <ScrollView
          className="flex-1"
          contentContainerStyle={{
            flexGrow: 1,
            paddingBottom: 20,
            paddingHorizontal: 24,
            paddingTop: 16,
          }}
          showsVerticalScrollIndicator={false}>
          <View className="flex-1 justify-between">
            <View className="items-center">
              <View className="rounded-full border border-white/20 bg-black/35 p-2">
                <Image
                  accessibilityLabel="OneSet logo"
                  className="h-9 w-9"
                  resizeMode="contain"
                  source={require('../assets/splash-icon-light.png')}
                />
              </View>
            </View>

            <View className="gap-4 pb-2">
              <Text className="max-w-[320px] font-display text-display text-dark-text-primary">
                {headline}
              </Text>
              <Link
                className="min-h-[56px] items-center justify-center rounded-2xl bg-brand-primary px-5 py-4 text-center font-body-semibold text-body text-white"
                href={cta.href}>
                {cta.label}
              </Link>
              <Link
                className="self-center px-4 py-2 text-center font-body text-body-sm text-dark-text-secondary"
                href={signIn.href}>
                {signIn.label}
              </Link>
            </View>
          </View>
        </ScrollView>
      </View>
    </SafeAreaView>
  );
}
