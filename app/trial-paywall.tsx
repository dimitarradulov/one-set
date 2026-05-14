import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function TrialPaywallPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Trial Paywall Placeholder"
      description="14-day free trial plus subscription gate. Dummy access gate content only.">
      <PlaceholderLink href="/fitness-disclaimer">
        Route Test: Continue to Fitness Disclaimer
      </PlaceholderLink>
      <PlaceholderLink href="/auth-prompt" variant="secondary">
        Route Test: Back to Auth Prompt
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
