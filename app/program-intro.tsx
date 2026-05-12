import { PlaceholderLink, PlaceholderScreen } from '@/components/route-shell';

const PREVIEW_SESSION_ID = 'session-a';

export default function ProgramIntroPlaceholderScreen() {
  return (
    <PlaceholderScreen
      title="Program Preview Placeholder"
      description="Preview route before entering the focused workout flow.">
      <PlaceholderLink href={`/workout/${PREVIEW_SESSION_ID}`}>
        Start Focused Session Preview
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
