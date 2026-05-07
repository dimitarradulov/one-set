import { Link } from 'expo-router';
import { Text } from 'react-native';

export default function HomeScreen() {
  return (
    <>
      <Text>Home</Text>
      <Link href="../workout/demo-session">Go to Workout</Link>
    </>
  );
}
