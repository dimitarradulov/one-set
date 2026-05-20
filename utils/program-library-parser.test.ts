import { readFileSync } from 'node:fs';

import { parseProgramLibraryMarkdown } from './program-library-parser';

const programLibraryMarkdown = readFileSync('docs/hit-workout-program-library.md', 'utf8');

describe('parseProgramLibraryMarkdown', () => {
  test('extracts programs from the documented Program Library', () => {
    const library = parseProgramLibraryMarkdown(programLibraryMarkdown);

    expect(library.programs).toHaveLength(15);
    expect(library.programs[0]).toMatchObject({
      number: 1,
      name: 'Foundation Full-Body HIT',
      slug: 'foundation-full-body-hit',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    });
    expect(library.programs[14]).toMatchObject({
      number: 15,
      name: 'Home Minimal Equipment HIT',
      recommendedDaysPerWeekMin: 2,
      recommendedDaysPerWeekMax: 3,
      workoutCount: 2,
    });
  });

  test('extracts selection groups from the documented Program Selection Logic', () => {
    const library = parseProgramLibraryMarkdown(programLibraryMarkdown);

    expect(library.selectionGroups.beginner).toEqual([
      'Beginner Strength-to-HIT Bridge',
      'Foundation Full-Body HIT',
      'Machine Circuit HIT',
    ]);
    expect(library.selectionGroups.advanced).toContain('Athletic Power HIT');
  });

  test('fails when a program is missing required recommendation source sections', () => {
    expect(() => parseProgramLibraryMarkdown('# Program 1 - Missing Sections')).toThrow(
      /missing a Best For section/
    );
  });
});
