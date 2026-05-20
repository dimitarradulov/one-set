import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { getRestTimerLinks } from '@/utils/workout-session-flow';
import { useLocalSearchParams } from 'expo-router';

export default function RestTimerScreen() {
  const { sessionId, exerciseId } = useLocalSearchParams<{
    sessionId: string;
    exerciseId: string;
  }>();
  const links = getRestTimerLinks({ sessionId, exerciseId });

  return (
    <PlaceholderScreen
      title="Rest Timer"
      description={`Session: ${sessionId} • Rest after exercise: ${exerciseId} — placeholder rest step.`}>
      <PlaceholderLink href={links.primary.href}>{links.primary.label}</PlaceholderLink>
      <PlaceholderLink href={links.secondary.href} variant="secondary">
        {links.secondary.label}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
