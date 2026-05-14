import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';

export default function OnboardingPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Onboarding Placeholder"
      description="Coach-style assessment placeholder before the program preview.">
      <PlaceholderLink href="/program-intro">Continue to Program Preview</PlaceholderLink>
    </PlaceholderScreen>
  );
}
