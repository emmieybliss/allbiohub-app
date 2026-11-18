import { Stack } from 'expo-router';
import { Image, Linking, ScrollView } from 'react-native';
import { AppText, Button } from '@/components/ui';
import { env } from '@/config/env';
import { openLink } from '@/lib/links';

export default function AboutScreen() {
  return (
    <ScrollView contentContainerStyle={{ padding: 24, gap: 14, alignItems: 'center' }}>
      <Stack.Screen options={{ title: 'About' }} />
      <Image source={require('../../assets/images/logo-mark.png')} style={{ width: 96, height: 96 }} accessibilityLabel="AllBioHub logo" />
      <AppText variant="headline">
        AllBio<AppText variant="headline" color="highlight">Hub</AppText>
      </AppText>
      <AppText color="muted" style={{ textAlign: 'center' }}>
        AllBioHub Media is a digital media and discovery platform covering African people, celebrity news, biography, technology, startups, founders, money and careers.
      </AppText>
      <AppText variant="subtitle" style={{ textAlign: 'center' }}>
        Read. Discover. Connect in one hub.
      </AppText>
      <Button icon="globe-outline" label="Visit allbiohub.com" onPress={() => Linking.openURL(env.siteUrl)} />
      {env.termsUrl ? <Button kind="text" label="Terms and conditions" onPress={() => openLink(env.termsUrl)} /> : null}
      <AppText variant="caption" color="subtle">
        Version {env.version}
      </AppText>
    </ScrollView>
  );
}
