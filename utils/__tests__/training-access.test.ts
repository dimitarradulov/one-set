import { getStartTrainingHref, getTrainingAccessStep } from '../training-access';

describe('training access decisions', () => {
  test('routes preview users through the create-account gate first', () => {
    expect(
      getStartTrainingHref({
        isAuthenticated: false,
        hasTrainingAccess: false,
        hasAcceptedFitnessDisclaimer: false,
      })
    ).toBe('/create-account');
  });

  test('routes authenticated users without access through the trial paywall', () => {
    expect(
      getStartTrainingHref({
        isAuthenticated: true,
        hasTrainingAccess: false,
        hasAcceptedFitnessDisclaimer: false,
      })
    ).toBe('/trial-paywall');
  });

  test('routes paid users through the disclaimer before training', () => {
    expect(
      getStartTrainingHref({
        isAuthenticated: true,
        hasTrainingAccess: true,
        hasAcceptedFitnessDisclaimer: false,
      })
    ).toBe('/fitness-disclaimer');
  });

  test('returns stable route content for the create-account step', () => {
    expect(getTrainingAccessStep('create-account')).toMatchObject({
      title: 'Account Creation Prompt',
      primaryHref: '/trial-paywall',
      secondaryHref: '/program-intro',
    });
  });
});
