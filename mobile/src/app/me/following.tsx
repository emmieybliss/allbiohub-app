import { Ionicons } from '@expo/vector-icons';
import { Stack, router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, FlatList, View } from 'react-native';
import { Row } from '@/components/Screen';
import { AppText, Chip, Divider, StateView } from '@/components/ui';
import { FeatureGate, FollowButton } from '@/features/community/components';
import type { FollowKind } from '@/features/community/models';
import { useFeature, useSession } from '@/features/community/store';
import { WatchlistRow } from '@/features/community/Watchlist';
import { paths } from '@/lib/deepLinks';
import { usePalette } from '@/theme';

const LABELS: Record<FollowKind, string> = { startup: 'Startups', topic: 'Topics', founder: 'Founders' };

const EMPTY: Record<FollowKind, [string, string]> = {
  startup: ['No startups yet', 'Tap Follow on a startup profile to get news about it.'],
  topic: ['No topics yet', 'Tap Follow on a topic to hear about new stories.'],
  founder: ['No founders yet', 'Tap Follow on a founder to hear about new stories.'],
};

/** Profile > Following: startups, topics and founders, each with an Unfollow button. */
function Following() {
  const p = usePalette();
  const kinds = [
    useFeature('startupFollows') && 'startup',
    useFeature('topicFollows') && 'topic',
    useFeature('founderFollows') && 'founder',
  ].filter(Boolean) as FollowKind[];
  const [chosen, setChosen] = useState<FollowKind | null>(null);
  const kind = chosen && kinds.includes(chosen) ? chosen : kinds[0];
  const follows = useSession((s) => s.follows);
  const loaded = useSession((s) => s.followsLoaded);

  if (!kind) {
    return <StateView icon="heart-outline" title="Following is coming soon" body="You will be able to follow startups, topics and founders." />;
  }
  const items = follows.filter((f) => f.target.kind === kind);

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      {kinds.length > 1 ? (
        <View style={{ flexDirection: 'row', gap: 8, paddingHorizontal: 16, paddingVertical: 8 }}>
          {kinds.map((k) => (
            <Chip key={k} label={LABELS[k]} selected={k === kind} onPress={() => setChosen(k)} />
          ))}
        </View>
      ) : null}
      {!loaded ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />
      ) : (
        <FlatList
          data={items}
          keyExtractor={(f) => f.target.id}
          contentContainerStyle={{ flexGrow: 1 }}
          ListEmptyComponent={
            <StateView
              icon="add-circle-outline"
              title={EMPTY[kind][0]}
              body={EMPTY[kind][1]}
              action={kind === 'topic' ? undefined : { label: 'Explore startups', onPress: () => router.navigate('/startups') }}
            />
          }
          renderItem={({ item }) =>
            kind === 'startup' ? (
              <WatchlistRow item={item} />
            ) : (
              <View>
                <Row
                  label={item.target.label}
                  onPress={() => router.push((kind === 'topic' ? paths.category(item.target.id) : paths.founder(item.target.id)) as never)}
                >
                  <Ionicons name={kind === 'topic' ? 'pricetag-outline' : 'person-outline'} size={22} color={p.accentText} />
                  <AppText variant="label" style={{ flex: 1 }}>
                    {item.target.label}
                  </AppText>
                  <FollowButton dense target={item.target} />
                </Row>
                <Divider />
              </View>
            )
          }
        />
      )}
    </View>
  );
}

export default function FollowingScreen() {
  return (
    <FeatureGate feature="accounts">
      <Stack.Screen options={{ title: 'Following' }} />
      <Following />
    </FeatureGate>
  );
}
