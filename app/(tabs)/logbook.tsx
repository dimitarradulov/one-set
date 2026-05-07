import { Link } from 'expo-router';
import { Text } from 'react-native';

export default function LogbookScreen() {
  return (
    <>
      <Text>Logbook</Text>
      <Link href="../home">Go to Home</Link>
    </>
  );
}
