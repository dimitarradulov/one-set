import type { ReactNode } from 'react';
import { Text, View } from 'react-native';

type PlaceholderScreenProps = {
  title: string;
  description: string;
  children?: ReactNode;
};

export default function PlaceholderScreen({
  title,
  description,
  children,
}: PlaceholderScreenProps) {
  return (
    <View className="flex-1 items-center justify-center gap-4 bg-dark-background px-5">
      <Text className="text-center font-display text-h1 text-dark-text-primary">{title}</Text>
      <Text className="text-center font-body text-body text-dark-text-secondary">
        {description}
      </Text>
      {children ? <View className="w-full max-w-sm gap-3">{children}</View> : null}
    </View>
  );
}
