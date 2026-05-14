import { welcomeContent } from '../(onboarding)/welcome-content';

describe('welcome content', () => {
  test('keeps onboarding copy and routes together in one module', () => {
    expect(welcomeContent.headline).toBe('Build muscle with fewer, harder, smarter workouts.');
    expect(welcomeContent.subtext).toBe(
      'OneSet creates HIT-based training programs built around your experience, recovery, schedule, and equipment.'
    );
    expect(welcomeContent.cta.label).toBe('Start Assessment');
    expect(welcomeContent.cta.href).toBe('/main-goal');
    expect(welcomeContent.helperText).toBe('Takes less than 2 minutes');
    expect(welcomeContent.footer.prompt).toBe('Already have an account?');
    expect(welcomeContent.footer.actionLabel).toBe('Sign in');
    expect(welcomeContent.footer.href).toBe('/auth-prompt');
    expect(welcomeContent.benefits).toEqual([
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
    ]);
  });
});
