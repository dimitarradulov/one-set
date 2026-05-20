import {
  ASSESSMENT_INTAKE_QUESTIONS,
  ASSESSMENT_INTAKE_TOTAL_STEPS,
  getAssessmentIntakeQuestion,
} from './assessment-intake';

describe('Assessment Intake questions', () => {
  test('defines the 11 answer-collection questions in order', () => {
    expect(ASSESSMENT_INTAKE_QUESTIONS.map((question) => question.id)).toEqual([
      'main-goal',
      'training-experience',
      'hit-experience',
      'days-available',
      'session-length',
      'equipment-access',
      'recovery-profile',
      'lifestyle-stress',
      'limitations',
      'training-direction',
      'failure-comfort',
    ]);
    expect(ASSESSMENT_INTAKE_QUESTIONS).toHaveLength(ASSESSMENT_INTAKE_TOTAL_STEPS);
  });

  test('keeps progress steps aligned with question order', () => {
    expect(ASSESSMENT_INTAKE_QUESTIONS.map((question) => question.progressStep)).toEqual([
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    ]);
  });

  test('defines route transitions for the Assessment Intake only', () => {
    expect(ASSESSMENT_INTAKE_QUESTIONS.map((question) => question.route)).toEqual([
      '/main-goal',
      '/training-experience',
      '/hit-experience',
      '/days-available',
      '/session-length',
      '/equipment-access',
      '/recovery-profile',
      '/lifestyle-stress',
      '/limitations',
      '/training-direction',
      '/failure-comfort',
    ]);
    expect(ASSESSMENT_INTAKE_QUESTIONS.map((question) => question.previousRoute)).toEqual([
      '/(onboarding)',
      '/main-goal',
      '/training-experience',
      '/hit-experience',
      '/days-available',
      '/session-length',
      '/equipment-access',
      '/recovery-profile',
      '/lifestyle-stress',
      '/limitations',
      '/training-direction',
    ]);
    expect(ASSESSMENT_INTAKE_QUESTIONS.map((question) => question.nextRoute)).toEqual([
      '/training-experience',
      '/hit-experience',
      '/days-available',
      '/session-length',
      '/equipment-access',
      '/recovery-profile',
      '/lifestyle-stress',
      '/limitations',
      '/training-direction',
      '/failure-comfort',
      '/result-calculation',
    ]);
  });

  test('keeps Assessment Intake scoped to answer collection before result calculation', () => {
    const routeLinks = ASSESSMENT_INTAKE_QUESTIONS.flatMap((question) => [
      question.route,
      question.previousRoute,
      question.nextRoute,
    ]);

    expect(
      ASSESSMENT_INTAKE_QUESTIONS.filter(
        (question) => question.nextRoute === '/result-calculation'
      ).map((question) => question.id)
    ).toEqual(['failure-comfort']);
    expect(routeLinks).not.toEqual(
      expect.arrayContaining([
        '/recommended-program',
        '/hit-principles',
        '/first-workout-preview',
        '/auth-prompt',
        '/trial-paywall',
      ])
    );
  });

  test('marks Limitations as the multi-select question', () => {
    expect(getAssessmentIntakeQuestion('limitations')).toMatchObject({
      answerKey: 'limitations',
      selectionMode: 'multiple',
      progressStep: 9,
    });
  });
});
