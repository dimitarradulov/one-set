import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getActiveExerciseLinks } from '@/utils/workout-session-flow';
import { useLocalSearchParams } from 'expo-router';

export default function ActiveExerciseScreen() {
  const { sessionId, exerciseId } = useLocalSearchParams<{
    sessionId: string;
    exerciseId: string;
  }>();
  const links = getActiveExerciseLinks({ sessionId, exerciseId });

  return (
    <PlaceholderScreen
      title="Active Exercise"
      description={`Session: ${sessionId} • Exercise: ${exerciseId} — placeholder one-exercise-at-a-time logging.`}>
      <PlaceholderLink href={links.primary.href}>{links.primary.label}</PlaceholderLink>
      <PlaceholderLink href={links.secondary.href} variant="secondary">
        {links.secondary.label}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
