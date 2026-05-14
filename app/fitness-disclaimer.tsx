import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

const PREVIEW_SESSION_ID = 'session-a';

export default function FitnessDisclaimerPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Fitness Disclaimer Placeholder"
      description="One-time legal and safety acknowledgment before real training starts. Dummy legal gate content only.">
      <PlaceholderLink href={`/workout/${PREVIEW_SESSION_ID}`}>
        Route Test: Continue to Workout Overview
      </PlaceholderLink>
      <PlaceholderLink href="/trial-paywall" variant="secondary">
        Route Test: Back to Trial Paywall
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
