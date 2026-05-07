import { Link } from 'expo-router';
import { Text } from 'react-native';

export default function OnboardingScreen() {
  return (
    <>
      <Text>Onboarding</Text>
      <Link href="../program-intro">Go to Program Intro</Link>
    </>
  );
}
