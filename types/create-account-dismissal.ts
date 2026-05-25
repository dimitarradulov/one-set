import type { Href } from 'expo-router';

export type CreateAccountDismissalNavigation = {
  canGoBack: () => boolean;
  back: () => void;
  replace: (href: Href) => void;
};
