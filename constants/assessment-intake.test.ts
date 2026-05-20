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
    expect(getAssessmentIntakeQuestion('main-goal')).toMatchObject({
      previousRoute: '/(onboarding)',
      nextRoute: '/training-experience',
    });
    expect(getAssessmentIntakeQuestion('failure-comfort')).toMatchObject({
      previousRoute: '/training-direction',
      nextRoute: '/result-calculation',
    });
  });

  test('marks Limitations as the multi-select question', () => {
    expect(getAssessmentIntakeQuestion('limitations')).toMatchObject({
      answerKey: 'limitations',
      selectionMode: 'multiple',
      progressStep: 9,
    });
  });
});
