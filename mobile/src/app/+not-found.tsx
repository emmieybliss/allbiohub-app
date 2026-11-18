import { Stack, router } from 'expo-router';
import { StateView } from '@/components/ui';

export default function NotFound() {
  return (
    <>
      <Stack.Screen options={{ title: '' }} />
      <StateView icon="compass-outline" title="Page not found" body="This link doesn't lead anywhere in the app." action={{ label: 'Go to Home', onPress: () => router.replace('/') }} />
    </>
  );
}
