import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';

type OnboardingStepScreenProps = {
  title: string;
  description: string;
  nextHref: string;
  nextLabel: string;
};

export function OnboardingStepScreen({
  title,
  description,
  nextHref,
  nextLabel,
}: OnboardingStepScreenProps) {
  return (
    <PlaceholderScreen title={title} description={description}>
      <PlaceholderLink href={nextHref}>{nextLabel}</PlaceholderLink>
    </PlaceholderScreen>
  );
}
