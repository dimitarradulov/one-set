import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getTrainingAccessStep } from '@/utils/training-access';

export default function FitnessDisclaimerPlaceholderScreen() {
  const step = getTrainingAccessStep('disclaimer');

  return (
    <PlaceholderScreen title={step.title} description={step.description}>
      <PlaceholderLink href={step.primaryHref}>{step.primaryLabel}</PlaceholderLink>
      <PlaceholderLink href={step.secondaryHref ?? '/trial-paywall'} variant="secondary">
        {step.secondaryLabel}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
