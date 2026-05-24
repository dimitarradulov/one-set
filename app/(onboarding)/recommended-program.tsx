import OnboardingStep from '@/components/OnboardingStep';
import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import { useAssessmentDraftStore } from '@/store/assessment-draft-store';
import { usePostAssessmentPreviewStore } from '@/store/post-assessment-preview-store';
import { getPostAssessmentPreviewStep } from '@/utils/post-assessment-preview';
import { buildRecommendedProgramDisplayFacts } from '@/utils/recommended-program-display';
import { Text, View } from 'react-native';

const MISSING_RECOMMENDATION_RECOVERY_DESCRIPTION =
  'OneSet needs to recalculate your starter program before this preview is ready.';
const MISSING_RECOMMENDATION_RECOVERY_HREF = '/result-calculation';
const MISSING_RECOMMENDATION_RECOVERY_LABEL = 'Return to Result Calculation';

export default function RecommendedProgramScreen() {
  const step = getPostAssessmentPreviewStep('recommended-program');
  const preparedState = usePostAssessmentPreviewStore((state) => state.preparedState);
  const preferredSessionLength = useAssessmentDraftStore((state) => state.preferredSessionLength);

  if (preparedState?.status !== 'ready') {
    return (
      <OnboardingStep
        title={step.title}
        description={MISSING_RECOMMENDATION_RECOVERY_DESCRIPTION}
        nextHref={MISSING_RECOMMENDATION_RECOVERY_HREF}
        nextLabel={MISSING_RECOMMENDATION_RECOVERY_LABEL}
      />
    );
  }

  const facts = buildRecommendedProgramDisplayFacts(
    preparedState.recommendation,
    preferredSessionLength
  );

  return (
    <View className="flex-1 items-center justify-center bg-dark-background px-5 py-6">
      <View className="w-full max-w-md gap-4">
        <Text className="text-center font-display text-h1 text-dark-text-primary">
          {step.title}
        </Text>
        <Text className="text-center font-body text-body text-dark-text-secondary">
          {step.description}
        </Text>
        <View className="gap-6 rounded-3xl border border-dark-border bg-dark-surface p-5">
          <View className="gap-1">
            <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
              Program
            </Text>
            <Text className="font-body-semibold text-h2 text-dark-text-primary">
              {facts.programName}
            </Text>
          </View>
          <View className="flex-row flex-wrap gap-4">
            <View className="min-w-[140px] flex-1 gap-1">
              <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
                Days/week
              </Text>
              <Text className="font-body text-body text-dark-text-primary">
                {facts.daysPerWeek}
              </Text>
            </View>
            <View className="min-w-[140px] flex-1 gap-1">
              <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
                Estimated workout length
              </Text>
              <Text className="font-body text-body text-dark-text-primary">
                {facts.estimatedWorkoutLength}
              </Text>
            </View>
            <View className="min-w-[140px] flex-1 gap-1">
              <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
                Starting Effort
              </Text>
              <Text className="font-body text-body text-dark-text-primary">
                {facts.startingEffort}
              </Text>
            </View>
            <View className="min-w-[140px] flex-1 gap-1">
              <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
                Recovery demand
              </Text>
              <Text className="font-body text-body text-dark-text-primary">
                {facts.recoveryDemand}
              </Text>
            </View>
          </View>
          <View className="gap-2">
            <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
              Why this program was chosen
            </Text>
            {facts.whyItFits.map((reason) => (
              <Text
                className="font-body text-body text-dark-text-primary"
                key={reason}>{`\u2022 ${reason}`}</Text>
            ))}
          </View>
          <View className="gap-1">
            <Text className="font-body-semibold text-caption uppercase tracking-[0.6px] text-dark-text-secondary">
              After 12 workouts
            </Text>
            <Text className="font-body text-body text-dark-text-primary">{facts.afterCycle}</Text>
          </View>
        </View>
        <PlaceholderLink href={step.nextHref}>{step.nextLabel}</PlaceholderLink>
        <Text className="text-center font-body text-body-sm text-dark-text-secondary">
          Free to start. No payment required.
        </Text>
      </View>
    </View>
  );
}
