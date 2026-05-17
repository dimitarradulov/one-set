import { welcomeContent } from '../(onboarding)/welcome-content';

describe('welcome content', () => {
  test('keeps only the simplified welcome copy and routes in one module', () => {
    expect(welcomeContent).toEqual({
      headline: 'Build more muscle by training less',
      cta: {
        label: 'Begin Assessment',
        href: '/main-goal',
      },
      signIn: {
        label: 'Sign in',
        href: '/auth-prompt',
      },
    });
  });
});
