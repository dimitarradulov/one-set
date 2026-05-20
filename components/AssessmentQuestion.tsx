import { Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import type { AssessmentQuestionOption } from '@/types/assessment-question';

type AssessmentQuestionProps<Value extends string = string> = {
  progressStep: number;
  totalSteps: number;
  question: string;
  helperText: string;
  options: readonly AssessmentQuestionOption<Value>[];
  selectedValues: readonly Value[];
  selectionMode?: 'single' | 'multiple';
  continueLabel: string;
  continueDisabled: boolean;
  disabled?: boolean;
  backLabel?: string;
  onBack?: () => void;
  onContinue: () => void;
  onSelectOption: (value: Value) => void;
};

export default function AssessmentQuestion<Value extends string = string>({
  progressStep,
  totalSteps,
  question,
  helperText,
  options,
  selectedValues,
  selectionMode = 'single',
  continueLabel,
  continueDisabled,
  disabled = false,
  backLabel = 'Back',
  onBack,
  onContinue,
  onSelectOption,
}: AssessmentQuestionProps<Value>) {
  const isContinueDisabled = disabled || continueDisabled;
  const progressRatio = totalSteps > 0 ? progressStep / totalSteps : 0;

  return (
    <SafeAreaView className="flex-1 bg-dark-background" edges={['top', 'bottom']}>
      <View className="flex-1 pt-4">
        <ScrollView
          testID="assessment-question-scroll"
          className="flex-1"
          contentContainerStyle={{ paddingBottom: 24, paddingHorizontal: 24 }}>
          {onBack ? (
            <View className="mb-6 flex-row items-center">
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={backLabel}
                accessibilityState={{ disabled }}
                className="min-h-[44px] justify-center rounded-xl border border-dark-border bg-dark-surface px-4"
                disabled={disabled}
                onPress={onBack}>
                <Text className="font-body-semibold text-body text-dark-text-primary">
                  {backLabel}
                </Text>
              </Pressable>
            </View>
          ) : null}

          <View className="mb-8">
            <Text className="mb-2 font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
              Question {progressStep} of {totalSteps}
            </Text>
            <View
              accessible
              accessibilityRole="progressbar"
              accessibilityValue={{
                min: 0,
                max: totalSteps,
                now: progressStep,
                text: `Question ${progressStep} of ${totalSteps}`,
              }}
              className="h-1.5 overflow-hidden rounded-full bg-dark-surface-muted">
              <View
                className="h-full rounded-full bg-brand-primary"
                style={{ width: `${progressRatio * 100}%` }}
              />
            </View>
          </View>

          <View className="mb-6 gap-2">
            <Text
              accessibilityRole="header"
              className="font-body-semibold text-h2 text-dark-text-primary">
              {question}
            </Text>
            <Text className="font-body text-body text-dark-text-secondary">{helperText}</Text>
          </View>

          <View className="gap-3">
            {options.map((option) => {
              const isSelected = selectedValues.includes(option.value);

              return (
                <Pressable
                  key={option.value}
                  accessibilityRole={selectionMode === 'multiple' ? 'checkbox' : 'button'}
                  accessibilityLabel={option.label}
                  accessibilityState={{
                    disabled,
                    selected: selectionMode === 'single' ? isSelected : undefined,
                    checked: selectionMode === 'multiple' ? isSelected : undefined,
                  }}
                  className={`min-h-[56px] flex-row items-center justify-between rounded-2xl border px-4 py-3 ${
                    isSelected
                      ? 'border-brand-primary bg-brand-primary-soft'
                      : 'border-dark-border bg-dark-surface'
                  }`}
                  disabled={disabled}
                  onPress={() => onSelectOption(option.value)}>
                  <Text
                    className={`flex-1 pr-3 font-body-semibold text-body ${
                      isSelected ? 'text-dark-text-primary' : 'text-dark-text-secondary'
                    }`}>
                    {option.label}
                  </Text>
                  {isSelected ? (
                    <Text className="font-body-semibold text-body text-brand-primary">✓</Text>
                  ) : null}
                </Pressable>
              );
            })}
          </View>
        </ScrollView>

        <View className="px-6 pb-8 pt-4">
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ disabled: isContinueDisabled }}
            className={`min-h-[56px] items-center justify-center rounded-2xl px-4 py-3 ${
              isContinueDisabled ? 'bg-dark-surface-muted' : 'bg-brand-primary'
            }`}
            disabled={isContinueDisabled}
            onPress={onContinue}>
            <Text
              className={`font-body-semibold text-body ${
                isContinueDisabled ? 'text-dark-text-muted' : 'text-dark-text-primary'
              }`}>
              {continueLabel}
            </Text>
          </Pressable>
        </View>
      </View>
    </SafeAreaView>
  );
}
