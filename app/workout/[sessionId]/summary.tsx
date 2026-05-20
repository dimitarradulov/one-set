import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getWorkoutSummaryLinks } from '@/utils/workout-session-flow';
import { useLocalSearchParams } from 'expo-router';

export default function WorkoutSummaryScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
  const links = getWorkoutSummaryLinks();

  return (
    <PlaceholderScreen
      title="Workout Summary"
      description={`Session context: ${sessionId} — placeholder post-workout summary.`}>
      <PlaceholderLink href={links.primary.href}>{links.primary.label}</PlaceholderLink>
      <PlaceholderLink href={links.secondary.href} variant="secondary">
        {links.secondary.label}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
