import type {
  AssessmentDraftAnswerKey,
  AssessmentDraftAnswers,
  AssessmentIntakeQuestion,
  AssessmentIntakeQuestionId,
} from '@/types/assessment';

export const selectedValuesFromAnswer = (
  answer: AssessmentDraftAnswers[AssessmentDraftAnswerKey]
) => {
  if (Array.isArray(answer)) {
    return answer;
  }

  return answer ? [answer] : [];
};

export const toggleAssessmentIntakeSelection = (
  question: Pick<AssessmentIntakeQuestion, 'selectionMode'>,
  selectedValues: readonly string[],
  value: string
) => {
  if (question.selectionMode === 'single') {
    return [value];
  }

  if (value === 'no_limitations') {
    return selectedValues.includes(value) ? [] : [value];
  }

  const withoutNoLimitations = selectedValues.filter((selected) => selected !== 'no_limitations');

  if (withoutNoLimitations.includes(value)) {
    return withoutNoLimitations.filter((selected) => selected !== value);
  }

  return [...withoutNoLimitations, value];
};

export const committedAnswerFromSelection = <Key extends AssessmentDraftAnswerKey>(
  question: Pick<AssessmentIntakeQuestion<AssessmentIntakeQuestionId, Key>, 'selectionMode'>,
  selectedValues: readonly string[]
): AssessmentDraftAnswers[Key] => {
  const answer =
    question.selectionMode === 'multiple' ? selectedValues : (selectedValues[0] ?? null);

  return answer as AssessmentDraftAnswers[Key];
};
