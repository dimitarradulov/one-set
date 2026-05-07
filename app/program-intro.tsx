import { Link } from 'expo-router';
import { Text } from 'react-native';

export default function ProgramIntroScreen() {
  return (
    <>
      <Text>Program Intro</Text>
      <Link href="./(tabs)/home">Go to Home</Link>
    </>
  );
}
