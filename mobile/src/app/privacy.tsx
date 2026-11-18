import { Stack } from 'expo-router';
import { ScrollView } from 'react-native';
import { AppText, Button } from '@/components/ui';
import { env } from '@/config/env';
import { useFeature } from '@/features/community/store';
import { openLink } from '@/lib/links';

export default function PrivacyScreen() {
  const accounts = useFeature('accounts');
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
      {accounts ? (
        <AppText>
          An account is optional. If you create one, Firebase stores your email address, the name, username, picture and bio you choose, and what you do in the
          community: comments, reactions, follows, poll votes, saved items and submissions. Your profile shows only what you allow in Account settings. You can
          delete your account and this data at any time from Account settings.
        </AppText>
      ) : null}
      {env.privacyPolicyUrl ? <Button label="Read the full privacy policy" onPress={() => openLink(env.privacyPolicyUrl)} /> : null}
    </ScrollView>
  );
}
