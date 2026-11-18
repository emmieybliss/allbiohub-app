import { Linking } from 'react-native';
import { StateView } from '@/components/ui';
import { sitePage } from '@/config/env';

/** Honest state while the startup add-on is off on the website. Nothing is faked. */
export function DirectoryUnavailable() {
  return (
    <StateView
      icon="rocket-outline"
      title="The startup directory is on its way"
      body="Meanwhile you can browse the full directory on allbiohub.com."
      action={{ label: 'Browse startups on allbiohub.com', icon: 'open-outline', onPress: () => Linking.openURL(sitePage('startups/')) }}
    />
  );
}
