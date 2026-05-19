import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

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
const PROGRESS_RATIO = PROGRESS_STEP / TOTAL_STEPS;

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
    <SafeAreaView className="flex-1 bg-dark-background" edges={['top', 'bottom']}>
      <View className="flex-1 px-6 pb-8 pt-4">
        <View className="mb-8">
          <Text className="mb-2 font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
            Question {PROGRESS_STEP} of {TOTAL_STEPS}
          </Text>
          <View className="h-1.5 overflow-hidden rounded-full bg-dark-surface-muted">
            <View
              className="h-full rounded-full bg-brand-primary"
              style={{ width: `${PROGRESS_RATIO * 100}%` }}
            />
          </View>
        </View>

        <View className="mb-6 gap-2">
          <Text className="font-body-semibold text-h2 text-dark-text-primary">
            What is your main goal right now?
          </Text>
          <Text className="font-body text-body text-dark-text-secondary">
            Pick the result you care about most right now.
          </Text>
        </View>

        <View className="flex-1 gap-3">
          {MAIN_GOAL_OPTIONS.map((option) => {
            const isSelected = selectedMainGoal === option.value;

            return (
              <Pressable
                key={option.value}
                accessibilityRole="button"
                accessibilityState={{ selected: isSelected }}
                className={`min-h-[56px] justify-center rounded-2xl border px-4 py-3 ${
                  isSelected
                    ? 'border-brand-primary bg-brand-primary-soft'
                    : 'border-dark-border bg-dark-surface'
                }`}
                onPress={() => setSelectedMainGoal(option.value)}>
                <Text
                  className={`font-body-semibold text-body ${
                    isSelected ? 'text-dark-text-primary' : 'text-dark-text-secondary'
                  }`}>
                  {option.label}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: isContinueDisabled }}
          className={`mt-4 min-h-[56px] items-center justify-center rounded-2xl px-4 py-3 ${
            isContinueDisabled ? 'bg-dark-surface-muted' : 'bg-brand-primary'
          }`}
          disabled={isContinueDisabled}
          onPress={handleContinue}>
          <Text
            className={`font-body-semibold text-body ${
              isContinueDisabled ? 'text-dark-text-muted' : 'text-dark-text-primary'
            }`}>
            Continue
          </Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}
