import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';

export default function HomePlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Home Placeholder"
      description="MVP home shell for the HIT training command center.">
      <PlaceholderLink href="/program-intro">Open Program Preview</PlaceholderLink>
    </PlaceholderScreen>
  );
}
