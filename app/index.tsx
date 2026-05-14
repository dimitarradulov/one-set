import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function Index() {
  return (
    <PlaceholderScreen
      title="OneSet Route Skeleton"
      description="Foundation shell for onboarding, preview, workout flow, and MVP tabs.">
      <PlaceholderLink href="/(onboarding)">Begin Assessment</PlaceholderLink>
      <PlaceholderLink href="/(tabs)" variant="secondary">
        Open Home Placeholder
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
