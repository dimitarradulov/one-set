import type { Href } from 'expo-router';

import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

type OnboardingStepProps = {
  title: string;
  description: string;
  nextHref: Href;
  nextLabel: string;
};

export default function OnboardingStep({
  title,
  description,
  nextHref,
  nextLabel,
}: OnboardingStepProps) {
  return (
    <PlaceholderScreen title={title} description={description}>
      <PlaceholderLink href={nextHref}>{nextLabel}</PlaceholderLink>
    </PlaceholderScreen>
  );
}
