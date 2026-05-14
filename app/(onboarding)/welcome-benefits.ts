import { MaterialCommunityIcons } from '@expo/vector-icons';
import type { ComponentProps } from 'react';

export type WelcomeBenefit = {
  title: string;
  description: string;
  icon: ComponentProps<typeof MaterialCommunityIcons>['name'];
};

export const welcomeBenefits = [
  {
    title: 'HIT-Only Programs',
    description: 'Low volume. High effort. Maximum results.',
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
] as const satisfies readonly WelcomeBenefit[];
