import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getTrainingAccessStep } from '@/utils/training-access';

export default function TrialPaywallPlaceholderScreen() {
  const step = getTrainingAccessStep('trial-paywall');

  return (
    <PlaceholderScreen title={step.title} description={step.description}>
      <PlaceholderLink href={step.primaryHref}>{step.primaryLabel}</PlaceholderLink>
      <PlaceholderLink href={step.secondaryHref ?? '/create-account'} variant="secondary">
        {step.secondaryLabel}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
