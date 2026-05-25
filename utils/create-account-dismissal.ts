import { PROGRAM_RECOMMENDATION_PREVIEW_HREF } from '@/constants/create-account-dismissal';
import type { CreateAccountDismissalNavigation } from '@/types/create-account-dismissal';

export const dismissCreateAccountPrompt = (navigation: CreateAccountDismissalNavigation): void => {
  if (navigation.canGoBack()) {
    navigation.back();
    return;
  }

  navigation.replace(PROGRAM_RECOMMENDATION_PREVIEW_HREF);
};
