import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';

export default function ProgramIntroPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Program Preview Placeholder"
      description="Preview route before entering the focused workout flow.">
      <PlaceholderLink href="/auth-prompt">Start Focused Session Preview</PlaceholderLink>
    </PlaceholderScreen>
  );
}
