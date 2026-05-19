import { useRouter } from 'expo-router';
import { useState } from 'react';

import AssessmentQuestion from '@/components/AssessmentQuestion';
import { useAssessmentDraftStore, type MainGoalId } from '@/store/assessment-draft-store';

const MAIN_GOAL_OPTIONS: { label: string; value: MainGoalId }[] = [
  { label: 'Build muscle', value: 'build_muscle' },
  { label: 'Get stronger', value: 'get_stronger' },
  { label: 'Recomp my body', value: 'recomp' },
  { label: 'Maintain muscle with less time', value: 'maintain_with_less_time' },
  { label: 'Return after a break', value: 'return_after_break' },
];

const PROGRESS_STEP = 1;
const TOTAL_STEPS = 11;

export default function MainGoalScreen() {
  const router = useRouter();
  const commitMainGoal = useAssessmentDraftStore((state) => state.commitMainGoal);
  const committedMainGoal = useAssessmentDraftStore((state) => state.mainGoal);
  const [selectedMainGoal, setSelectedMainGoal] = useState<MainGoalId | null>(committedMainGoal);

  const isContinueDisabled = selectedMainGoal === null;

  const handleContinue = () => {
    if (!selectedMainGoal) {
      return;
    }

    commitMainGoal(selectedMainGoal);
    router.push('/training-experience');
  };

  return (
    <AssessmentQuestion
      continueDisabled={isContinueDisabled}
      continueLabel="Continue"
      helperText="Pick the result you care about most right now."
      options={MAIN_GOAL_OPTIONS}
      progressStep={PROGRESS_STEP}
      selectedValue={selectedMainGoal}
      totalSteps={TOTAL_STEPS}
      question="What is your main goal right now?"
      onContinue={handleContinue}
      onSelectOption={setSelectedMainGoal}
    />
  );
}
