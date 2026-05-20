import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getWorkoutOverviewLinks } from '@/utils/workout-session-flow';
import { useLocalSearchParams } from 'expo-router';

export default function WorkoutOverviewScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
  const links = getWorkoutOverviewLinks({ sessionId });

  return (
    <PlaceholderScreen
      title="Workout Overview"
      description={`Session context: ${sessionId} — placeholder pre-workout overview content.`}>
      <PlaceholderLink href={links.primary.href}>{links.primary.label}</PlaceholderLink>
      <PlaceholderLink href={links.secondary.href} variant="secondary">
        {links.secondary.label}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
