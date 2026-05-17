import { MaterialCommunityIcons } from '@expo/vector-icons';
import type { ComponentProps } from 'react';
import { Text, View } from 'react-native';

export type WelcomeBenefitRowProps = {
  title: string;
  description: string;
  icon: ComponentProps<typeof MaterialCommunityIcons>['name'];
};

export function WelcomeBenefitRow({ description, icon, title }: WelcomeBenefitRowProps) {
  return (
    <View className="flex-row items-center gap-4 rounded-2xl border border-dark-border bg-dark-surface px-4 py-4">
      <View className="h-11 w-11 items-center justify-center rounded-2xl bg-brand-primary-soft">
        <MaterialCommunityIcons color="#A78BFA" name={icon} size={22} />
      </View>
      <View className="flex-1 gap-1">
        <Text className="font-body-semibold text-body text-dark-text-primary">{title}</Text>
        <Text className="font-body text-body-sm text-dark-text-secondary">{description}</Text>
      </View>
    </View>
  );
}
