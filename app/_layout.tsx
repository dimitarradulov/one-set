import '../global.css';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { Stack } from 'expo-router';

export const unstable_settings = {
  initialRouteName: '(onboarding)',
};

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <Stack>
        <Stack.Screen name="(onboarding)" options={{ headerShown: false }} />
        <Stack.Screen name="program-intro" options={{ title: 'Program Intro' }} />
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="workout/[sessionId]" options={{ title: 'Workout' }} />
        <Stack.Screen name="summary/[sessionId]" options={{ title: 'Summary' }} />
      </Stack>
    </SafeAreaProvider>
  );
}
