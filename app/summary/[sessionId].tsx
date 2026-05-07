import { Link } from 'expo-router';
import { Text } from 'react-native';

export default function SummaryScreen() {
  return (
    <>
      <Text>Summary</Text>
      <Link href="../home">Go to Home</Link>
      <Link href="../logbook">Go to Logbook</Link>
    </>
  );
}
