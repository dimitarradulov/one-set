import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function AuthPromptPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Auth Prompt Placeholder"
      description="Create an account to save your progress. Dummy access gate content only.">
      <PlaceholderLink href="/trial-paywall">Route Test: Continue to Trial Paywall</PlaceholderLink>
      <PlaceholderLink href="/program-intro" variant="secondary">
        Route Test: Back to Program Preview
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
