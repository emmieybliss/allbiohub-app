import { Stack, router } from 'expo-router';
import { FlatList } from 'react-native';
import { StateView } from '@/components/ui';
import { FeatureGate } from '@/features/community/components';
import { useSession } from '@/features/community/store';
import { WatchlistRow } from '@/features/community/Watchlist';
import { usePalette } from '@/theme';

/** My Startup Watchlist: followed startups with their details and latest AllBioHub story. */
function Watchlist() {
  const p = usePalette();
  const items = useSession((s) => s.follows).filter((f) => f.target.kind === 'startup');
  return (
    <FlatList
      style={{ backgroundColor: p.background }}
      data={items}
      keyExtractor={(f) => f.target.id}
      renderItem={({ item }) => <WatchlistRow item={item} />}
      contentContainerStyle={{ flexGrow: 1 }}
      ListEmptyComponent={
        <StateView
          icon="rocket-outline"
          title="Your watchlist is empty"
          body="Follow startups to keep track of them here."
          action={{ label: 'Explore startups', onPress: () => router.navigate('/startups') }}
        />
      }
    />
  );
}

export default function WatchlistScreen() {
  return (
    <FeatureGate feature="startupFollows">
      <Stack.Screen options={{ title: 'My Startup Watchlist' }} />
      <Watchlist />
    </FeatureGate>
  );
}
