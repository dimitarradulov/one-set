import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getTrainingAccessStep } from '@/utils/training-access';

export default function AuthPromptPlaceholderScreen() {
  const step = getTrainingAccessStep('auth-prompt');

  return (
    <PlaceholderScreen title={step.title} description={step.description}>
      <PlaceholderLink href={step.primaryHref}>{step.primaryLabel}</PlaceholderLink>
      <PlaceholderLink href={step.secondaryHref ?? '/program-intro'} variant="secondary">
        {step.secondaryLabel}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
