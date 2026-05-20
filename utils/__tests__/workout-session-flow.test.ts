import {
  getActiveExerciseLinks,
  getPreviewExerciseHref,
  getPreviewWorkoutHref,
  getRestTimerLinks,
  getWorkoutOverviewLinks,
  getWorkoutSummaryLinks,
} from '../workout-session-flow';

describe('Workout Session flow', () => {
  test('builds preview entry links from one place', () => {
    expect(getPreviewWorkoutHref()).toBe('/workout/session-a');
    expect(getPreviewExerciseHref()).toBe('/workout/session-a/exercise/1');
  });

  test('builds overview and active exercise links', () => {
    expect(getWorkoutOverviewLinks({ sessionId: 'session-a' }).primary.href).toBe(
      '/workout/session-a/exercise/1'
    );
    expect(getActiveExerciseLinks({ sessionId: 'session-a', exerciseId: '2' })).toMatchObject({
      primary: {
        href: '/workout/session-a/rest/2',
      },
      secondary: {
        href: '/workout/session-a',
      },
    });
  });

  test('builds rest and summary links', () => {
    expect(getRestTimerLinks({ sessionId: 'session-a', exerciseId: '1' })).toMatchObject({
      primary: {
        href: '/workout/session-a/exercise/2',
        label: 'Continue to Exercise 2',
      },
      secondary: {
        href: '/workout/session-a/summary',
      },
    });

    expect(getWorkoutSummaryLinks()).toMatchObject({
      primary: {
        href: '/(tabs)',
      },
      secondary: {
        href: '/(tabs)/logbook',
      },
    });
  });
});
