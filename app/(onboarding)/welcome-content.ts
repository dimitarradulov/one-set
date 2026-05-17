import { MaterialCommunityIcons } from '@expo/vector-icons';
import type { ComponentProps } from 'react';

export type WelcomeBenefit = {
  title: string;
  description: string;
  icon: ComponentProps<typeof MaterialCommunityIcons>['name'];
};

export const welcomeContent = {
  headline: 'Build muscle with fewer, harder, smarter workouts.',
  subtext:
    'OneSet creates HIT-based training programs built around your experience, recovery, schedule, and equipment.',
  cta: {
    label: 'Start Assessment',
    href: '/main-goal' as const,
  },
  helperText: 'Takes less than 2 minutes',
  footer: {
    prompt: 'Already have an account?',
    actionLabel: 'Sign in',
    href: '/auth-prompt' as const,
  },
  benefits: [
    {
      title: 'HIT-Only Programs',
      description: 'Less volume. More effort. Better results.',
      icon: 'dumbbell',
    },
    {
      title: 'Track What Matters',
      description: 'Your logbook drives your progress.',
      icon: 'clipboard-text-outline',
    },
    {
      title: 'Progress Over Time',
      description: 'Intelligent rules guide your next steps.',
      icon: 'chart-line',
    },
    {
      title: 'Recover to Grow',
      description: 'Training hard means recovering smart.',
      icon: 'heart-pulse',
    },
  ] as const satisfies readonly WelcomeBenefit[],
} as const;
