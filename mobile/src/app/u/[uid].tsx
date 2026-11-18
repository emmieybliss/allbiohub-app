import { Stack, useLocalSearchParams } from 'expo-router';
import { ActivityIndicator, ScrollView } from 'react-native';
import { pickOption } from '@/components/OptionSheet';
import { ErrorView, IconButton, StateView } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate, ProfileHeader, reportContent } from '@/features/community/components';
import { showCommunityError } from '@/features/community/gate';
import { usePublicProfile } from '@/features/community/hooks';
import { useSession } from '@/features/community/store';
import { showMessage } from '@/lib/toast';
import { usePalette } from '@/theme';

/** Another person's public profile, with Report and Block. */
function PublicProfile() {
  const p = usePalette();
  const { uid } = useLocalSearchParams<{ uid: string }>();
  const q = usePublicProfile(uid);
  const me = useSession((s) => s.user?.uid);
  const blocked = useSession((s) => s.blocked.includes(uid));

  const menu = async () => {
    const choice = await pickOption([
      { value: 'report', label: 'Report', icon: 'flag-outline' },
      { value: 'block', label: blocked ? 'Unblock' : 'Block', icon: 'ban-outline' },
    ]);
    if (choice === 'report') await reportContent('user', uid);
    if (choice === 'block') {
      try {
        await community().api.setBlocked(uid, !blocked);
        showMessage(blocked ? 'Unblocked' : 'Blocked. Their comments are hidden.');
      } catch (e) {
        showCommunityError(e);
      }
    }
  };

  return (
    <>
      <Stack.Screen
        options={{
          title: '',
          headerRight: me && me !== uid ? () => <IconButton icon="ellipsis-vertical" label="More" onPress={menu} /> : undefined,
        }}
      />
      {q.isPending ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />
      ) : q.isError ? (
        <ErrorView error={q.error} onRetry={() => q.refetch()} />
      ) : q.data ? (
        <ScrollView style={{ backgroundColor: p.background }} contentContainerStyle={{ padding: 24 }}>
          <ProfileHeader profile={q.data} />
        </ScrollView>
      ) : (
        <StateView icon="lock-closed-outline" title="This profile is private" body="Only their name and username are shown with their comments." />
      )}
    </>
  );
}

export default function PublicProfileScreen() {
  return (
    <FeatureGate feature="communityProfiles">
      <PublicProfile />
    </FeatureGate>
  );
}
