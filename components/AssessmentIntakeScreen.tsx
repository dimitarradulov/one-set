import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';

import AssessmentQuestion from '@/components/AssessmentQuestion';
import {
  ASSESSMENT_INTAKE_TOTAL_STEPS,
  getAssessmentIntakeQuestion,
} from '@/constants/assessment-intake';
import { useAssessmentDraftStore } from '@/store/assessment-draft-store';
import type { AssessmentIntakeQuestionId } from '@/types/assessment';
import {
  committedAnswerFromSelection,
  selectedValuesFromAnswer,
  toggleAssessmentIntakeSelection,
} from '@/utils/assessment-intake-flow';

type AssessmentIntakeScreenProps = {
  questionId: AssessmentIntakeQuestionId;
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
    setSelectedValues((currentValues) =>
      toggleAssessmentIntakeSelection(question, currentValues, value)
    );
  };

  const handleContinue = () => {
    if (isContinueDisabled) {
      return;
    }

    const answer = committedAnswerFromSelection(question, selectedValues);

    commitAnswer(question.answerKey, answer);
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
