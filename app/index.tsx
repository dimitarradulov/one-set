import { Redirect } from 'expo-router';

import { INITIAL_ROUTE } from '@/constants/routes';

export default function Index() {
  return <Redirect href={INITIAL_ROUTE} />;
}
