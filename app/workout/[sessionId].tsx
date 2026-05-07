import { Link } from 'expo-router';
import { Text } from 'react-native';

export default function WorkoutScreen() {
  return (
    <>
      <Text>Workout</Text>
      <Link href="../summary/demo-session">Go to Summary</Link>
    </>
  );
}
