import WelcomeHero from '@/components/WelcomeHero';

import { welcomeContent } from './welcome-content';

export default function OnboardingWelcomeScreen() {
  return (
    <WelcomeHero
      cta={welcomeContent.cta}
      headline={welcomeContent.headline}
      signIn={welcomeContent.signIn}
    />
  );
}
