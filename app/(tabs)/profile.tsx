import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function ProfilePlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Profile"
      description="Dummy Profile content for quiet account, subscription, assessment, preferences, and legal settings.">
      <PlaceholderLink href="/create-account">Route Test: Account Access</PlaceholderLink>
      <PlaceholderLink href="/fitness-disclaimer" variant="secondary">
        Route Test: Legal Screen
      </PlaceholderLink>
      <PlaceholderLink href="/recommended-program" variant="secondary">
        Route Test: Assessment Target
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
