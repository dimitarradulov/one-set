import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';

import AssessmentQuestion from '@/components/AssessmentQuestion';
import {
  ASSESSMENT_INTAKE_TOTAL_STEPS,
  getAssessmentIntakeQuestion,
} from '@/constants/assessment-intake';
import type {
  AssessmentDraftAnswerKey,
  AssessmentDraftAnswers,
  AssessmentIntakeQuestionId,
} from '@/types/assessment';
import { useAssessmentDraftStore } from '@/store/assessment-draft-store';

type AssessmentIntakeScreenProps = {
  questionId: AssessmentIntakeQuestionId;
};

const selectedValuesFromAnswer = (answer: AssessmentDraftAnswers[AssessmentDraftAnswerKey]) => {
  if (Array.isArray(answer)) {
    return answer;
  }

  return answer ? [answer] : [];
};

const toggleMultipleValue = (selectedValues: string[], value: string) => {
  if (value === 'no_limitations') {
    return selectedValues.includes(value) ? [] : [value];
  }

  const withoutNoLimitations = selectedValues.filter((selected) => selected !== 'no_limitations');

  if (withoutNoLimitations.includes(value)) {
    return withoutNoLimitations.filter((selected) => selected !== value);
  }

  return [...withoutNoLimitations, value];
};

export default function AssessmentIntakeScreen({ questionId }: AssessmentIntakeScreenProps) {
  const router = useRouter();
  const question = useMemo(() => getAssessmentIntakeQuestion(questionId), [questionId]);
  const committedAnswer = useAssessmentDraftStore((state) => state[question.answerKey]);
  const commitAnswer = useAssessmentDraftStore((state) => state.commitAnswer);
  const isHydrated = useAssessmentDraftStore((state) => state.isHydrated);
  const [selectedValues, setSelectedValues] = useState<string[]>(
    selectedValuesFromAnswer(committedAnswer)
  );

  useEffect(() => {
    if (isHydrated) {
      setSelectedValues(selectedValuesFromAnswer(committedAnswer));
    }
  }, [committedAnswer, isHydrated]);

  const isContinueDisabled = !isHydrated || selectedValues.length === 0;

  const handleSelectOption = (value: string) => {
    setSelectedValues((currentValues) => {
      if (question.selectionMode === 'multiple') {
        return toggleMultipleValue(currentValues, value);
      }

      return [value];
    });
  };

  const handleContinue = () => {
    if (isContinueDisabled) {
      return;
    }

    const answer =
      question.selectionMode === 'multiple' ? selectedValues : (selectedValues[0] ?? null);

    commitAnswer(question.answerKey, answer as AssessmentDraftAnswers[typeof question.answerKey]);
    router.push(question.nextRoute);
  };

  const handleBack = () => {
    router.replace(question.previousRoute);
  };

  return (
    <AssessmentQuestion
      backLabel="Back"
      continueDisabled={isContinueDisabled}
      continueLabel="Continue"
      disabled={!isHydrated}
      helperText={question.helperText}
      options={question.options}
      progressStep={question.progressStep}
      selectedValues={selectedValues}
      selectionMode={question.selectionMode}
      totalSteps={ASSESSMENT_INTAKE_TOTAL_STEPS}
      question={question.question}
      onBack={handleBack}
      onContinue={handleContinue}
      onSelectOption={handleSelectOption}
    />
  );
}
