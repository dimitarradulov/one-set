import WelcomeHero from '@/components/WelcomeHero';

import { welcomeContent } from '../../constants/welcome-content';

export default function OnboardingWelcomeScreen() {
  return (
    <WelcomeHero
      cta={welcomeContent.cta}
      headline={welcomeContent.headline}
      subheadline={welcomeContent.subheadline}
      signIn={welcomeContent.signIn}
    />
  );
}
