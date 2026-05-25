import type { ProgramSelectionLevel } from '@/types/program';

export const PROGRAM_HEADING_PATTERN = /^# Program (?<number>\d+) [—-] (?<name>.+)$/gm;

export const SELECTION_LEVEL_HEADINGS: Record<string, ProgramSelectionLevel> = {
  Beginner: 'beginner',
  'Late Beginner': 'late_beginner',
  Intermediate: 'intermediate',
  Advanced: 'advanced',
};
