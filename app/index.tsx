import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';

export default function Index() {
  return (
    <PlaceholderScreen
      title="OneSet Route Skeleton"
      description="Foundation shell for onboarding, preview, workout flow, and MVP tabs.">
      <PlaceholderLink href="/(onboarding)">Begin Onboarding Placeholder</PlaceholderLink>
      <PlaceholderLink href="/(tabs)" variant="secondary">
        Open Home Placeholder
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
