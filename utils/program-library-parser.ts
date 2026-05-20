export type ProgramLibraryEntry = {
  number: number;
  name: string;
  slug: string;
  bestFor: string;
  weeklySchedule: string;
  recommendedDaysPerWeekMin: number | null;
  recommendedDaysPerWeekMax: number | null;
  workoutCount: number;
};

export type ProgramSelectionLevel = 'beginner' | 'late_beginner' | 'intermediate' | 'advanced';

export type ProgramLibrary = {
  programs: ProgramLibraryEntry[];
  selectionGroups: Record<ProgramSelectionLevel, string[]>;
};

const PROGRAM_HEADING_PATTERN = /^# Program (?<number>\d+) [—-] (?<name>.+)$/gm;

const SELECTION_LEVEL_HEADINGS: Record<string, ProgramSelectionLevel> = {
  Beginner: 'beginner',
  'Late Beginner': 'late_beginner',
  Intermediate: 'intermediate',
  Advanced: 'advanced',
};

const slugifyProgramName = (name: string) =>
  name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

const getSection = (markdown: string, heading: string, nextHeadingLevel = '##') => {
  const headingPattern = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const sectionPattern = new RegExp(
    `(?:^|\\n)${nextHeadingLevel} ${headingPattern}\\n\\n(?<body>[\\s\\S]*?)(?=\\n${nextHeadingLevel} |\\n# |$)`
  );

  return sectionPattern.exec(markdown)?.groups?.body.trim() ?? '';
};

const getProgramSections = (markdown: string) => {
  const matches = [...markdown.matchAll(PROGRAM_HEADING_PATTERN)];

  return matches.map((match, index) => {
    const nextMatch = matches[index + 1];
    const start = match.index ?? 0;
    const end = nextMatch?.index ?? markdown.length;

    return {
      number: Number(match.groups?.number),
      name: match.groups?.name.trim() ?? '',
      markdown: markdown.slice(start, end),
    };
  });
};

const parseRecommendedDays = (weeklySchedule: string) => {
  const everyRange = /every \*\*(?<min>\d+)[–-](?<max>\d+) days\*\*/i.exec(weeklySchedule);

  if (everyRange?.groups) {
    return {
      recommendedDaysPerWeekMin: 1,
      recommendedDaysPerWeekMax: 2,
    };
  }

  const range = /Train \*\*(?<min>\d+)[–-](?<max>\d+) days per week\*\*/i.exec(weeklySchedule);

  if (range?.groups) {
    return {
      recommendedDaysPerWeekMin: Number(range.groups.min),
      recommendedDaysPerWeekMax: Number(range.groups.max),
    };
  }

  const exact = /Train \*\*(?<days>\d+) days per week\*\*/i.exec(weeklySchedule);

  if (exact?.groups) {
    const days = Number(exact.groups.days);

    return {
      recommendedDaysPerWeekMin: days,
      recommendedDaysPerWeekMax: days,
    };
  }

  return {
    recommendedDaysPerWeekMin: null,
    recommendedDaysPerWeekMax: null,
  };
};

const countWorkoutSections = (programMarkdown: string) =>
  [...programMarkdown.matchAll(/^## (Workout|Day|Upper|Lower|Chest Priority Example)/gm)].length;

const parseSelectionGroups = (markdown: string): Record<ProgramSelectionLevel, string[]> => {
  const selectionLogic = markdown
    .split('# Program Selection Logic for the App')[1]
    ?.split('---')[0];

  if (!selectionLogic) {
    throw new Error('Program library is missing Program Selection Logic for the App');
  }

  const groups: Record<ProgramSelectionLevel, string[]> = {
    beginner: [],
    late_beginner: [],
    intermediate: [],
    advanced: [],
  };

  for (const [heading, level] of Object.entries(SELECTION_LEVEL_HEADINGS)) {
    const body = getSection(selectionLogic, heading);
    const names = [...body.matchAll(/^\d+\.\s+(?<name>.+)$/gm)].map(
      (match) => match.groups?.name.trim() ?? ''
    );

    if (names.length === 0) {
      throw new Error(`Program library selection logic is missing ${heading} entries`);
    }

    groups[level] = names;
  }

  return groups;
};

export const parseProgramLibraryMarkdown = (markdown: string): ProgramLibrary => {
  const programSections = getProgramSections(markdown);

  if (programSections.length === 0) {
    throw new Error('Program library markdown contains no programs');
  }

  const programs = programSections.map(({ number, name, markdown: programMarkdown }) => {
    const bestFor = getSection(programMarkdown, 'Best For');
    const weeklySchedule = getSection(programMarkdown, 'Weekly Schedule');

    if (!bestFor) {
      throw new Error(`Program ${number} is missing a Best For section`);
    }

    if (!weeklySchedule) {
      throw new Error(`Program ${number} is missing a Weekly Schedule section`);
    }

    return {
      number,
      name,
      slug: slugifyProgramName(name),
      bestFor,
      weeklySchedule,
      ...parseRecommendedDays(weeklySchedule),
      workoutCount: countWorkoutSections(programMarkdown),
    };
  });

  return {
    programs,
    selectionGroups: parseSelectionGroups(markdown),
  };
};
