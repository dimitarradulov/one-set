import {
  committedAnswerFromSelection,
  selectedValuesFromAnswer,
  toggleAssessmentIntakeSelection,
} from '../assessment-intake-flow';

describe('Assessment Intake flow', () => {
  test('adapts committed Assessment Draft answers to selected values', () => {
    expect(selectedValuesFromAnswer(null)).toEqual([]);
    expect(selectedValuesFromAnswer('build_muscle')).toEqual(['build_muscle']);
    expect(selectedValuesFromAnswer(['shoulders', 'wrists'])).toEqual(['shoulders', 'wrists']);
  });

  test('replaces single-select choices', () => {
    expect(
      toggleAssessmentIntakeSelection(
        {
          selectionMode: 'single',
        },
        ['build_muscle'],
        'get_stronger'
      )
    ).toEqual(['get_stronger']);
  });

  test('toggles multi-select choices on and off', () => {
    expect(
      toggleAssessmentIntakeSelection(
        {
          selectionMode: 'multiple',
        },
        [],
        'shoulders'
      )
    ).toEqual(['shoulders']);

    expect(
      toggleAssessmentIntakeSelection(
        {
          selectionMode: 'multiple',
        },
        ['shoulders'],
        'wrists'
      )
    ).toEqual(['shoulders', 'wrists']);

    expect(
      toggleAssessmentIntakeSelection(
        {
          selectionMode: 'multiple',
        },
        ['shoulders', 'wrists'],
        'shoulders'
      )
    ).toEqual(['wrists']);
  });

  test('keeps no limitations mutually exclusive in multi-select choices', () => {
    expect(
      toggleAssessmentIntakeSelection(
        {
          selectionMode: 'multiple',
        },
        ['shoulders'],
        'no_limitations'
      )
    ).toEqual(['no_limitations']);

    expect(
      toggleAssessmentIntakeSelection(
        {
          selectionMode: 'multiple',
        },
        ['no_limitations'],
        'wrists'
      )
    ).toEqual(['wrists']);
  });

  test('commits the selected value shape expected by the Assessment Draft', () => {
    expect(
      committedAnswerFromSelection(
        {
          selectionMode: 'single',
        },
        ['recomp']
      )
    ).toBe('recomp');
    expect(
      committedAnswerFromSelection(
        {
          selectionMode: 'single',
        },
        []
      )
    ).toBeNull();

    expect(
      committedAnswerFromSelection(
        {
          selectionMode: 'multiple',
        },
        ['shoulders', 'wrists']
      )
    ).toEqual(['shoulders', 'wrists']);
  });
});
