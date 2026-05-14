import { Redirect } from 'expo-router';

const initialRoute = '/(onboarding)' as const;

export default function Index() {
  return <Redirect href={initialRoute} />;
}
