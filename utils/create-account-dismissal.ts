import type { Href } from 'expo-router';

const PROGRAM_RECOMMENDATION_PREVIEW_HREF: Href = '/recommended-program';

export type CreateAccountDismissalNavigation = {
  canGoBack: () => boolean;
  back: () => void;
  replace: (href: Href) => void;
};

export const dismissCreateAccountPrompt = (navigation: CreateAccountDismissalNavigation): void => {
  if (navigation.canGoBack()) {
    navigation.back();
    return;
  }

  navigation.replace(PROGRAM_RECOMMENDATION_PREVIEW_HREF);
};
