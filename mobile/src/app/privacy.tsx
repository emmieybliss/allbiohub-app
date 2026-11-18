import { Stack } from 'expo-router';
import { ScrollView } from 'react-native';
import { AppText, Button } from '@/components/ui';
import { env } from '@/config/env';
import { openLink } from '@/lib/links';

export default function PrivacyScreen() {
  return (
    <ScrollView contentContainerStyle={{ padding: 20, gap: 14 }}>
      <Stack.Screen options={{ title: 'Privacy' }} />
      <AppText>
        You can use AllBioHub without an account. Saved stories, settings and recent searches are stored on this device. The app loads stories and startup profiles
        from allbiohub.com.
      </AppText>
      <AppText>
        If you allow notifications, Firebase Cloud Messaging gives this phone an anonymous token and the topics you chose, so AllBioHub can send them. No name,
        email or contacts are collected.
      </AppText>
      {env.privacyPolicyUrl ? <Button label="Read the full privacy policy" onPress={() => openLink(env.privacyPolicyUrl)} /> : null}
    </ScrollView>
  );
}
