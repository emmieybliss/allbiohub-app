import { Stack } from 'expo-router';
import { ScrollView } from 'react-native';
import { AppText } from '@/components/ui';
import { TopicPicker } from '@/features/onboarding/TopicPicker';
import { usePreferences } from '@/stores/preferences';

export default function TopicsScreen() {
  const interests = usePreferences((s) => s.interestSlugs);
  const setInterests = usePreferences((s) => s.setInterests);
  return (
    <ScrollView contentContainerStyle={{ padding: 16, gap: 16 }}>
      <Stack.Screen options={{ title: 'Your topics' }} />
      <AppText color="muted">These come first on Home.</AppText>
      <TopicPicker selected={interests} onChange={setInterests} />
    </ScrollView>
  );
}
