import PlaceholderLink from '@/components/route-shell/PlaceholderLink';
import PlaceholderScreen from '@/components/route-shell/PlaceholderScreen';
import { PREVIEW_TRAINING_ACCESS_STATE } from '@/constants/training-access';
import { getStartTrainingHref, getTrainingAccessStep } from '@/utils/training-access';

export default function ProgramIntroPlaceholderScreen() {
  const step = getTrainingAccessStep('program-preview');

  return (
    <PlaceholderScreen title={step.title} description={step.description}>
      <PlaceholderLink href={getStartTrainingHref(PREVIEW_TRAINING_ACCESS_STATE)}>
        {step.primaryLabel}
      </PlaceholderLink>
    </PlaceholderScreen>
  );
}
