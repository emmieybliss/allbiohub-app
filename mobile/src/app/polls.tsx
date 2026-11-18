import { Stack } from 'expo-router';
import { ActivityIndicator, RefreshControl, ScrollView } from 'react-native';
import { AppText, ErrorView, StateView } from '@/components/ui';
import { FeatureGate } from '@/features/community/components';
import { useActivePolls, usePastPolls, useQuestionOfTheDay } from '@/features/community/hooks';
import { PollCard } from '@/features/community/PollCard';
import { usePalette } from '@/theme';

/** Open polls, then closed ones. */
function Polls() {
  const p = usePalette();
  const active = useActivePolls();
  const past = usePastPolls();
  const qotd = useQuestionOfTheDay();
  if (active.isPending) return <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />;
  if (active.isError) return <ErrorView error={active.error} onRetry={() => active.refetch()} />;
  return (
    <ScrollView
      style={{ backgroundColor: p.background }}
      contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: 32 }}
      refreshControl={<RefreshControl refreshing={false} onRefresh={() => void Promise.all([active.refetch(), past.refetch(), qotd.refetch()])} />}
    >
      {qotd.data ? <PollCard poll={qotd.data} /> : null}
      {active.data.map((poll) => (
        <PollCard key={poll.id} poll={poll} />
      ))}
      {!active.data.length && !qotd.data ? <StateView icon="stats-chart-outline" title="No open polls" body="AllBioHub editors post new polls regularly." /> : null}
      {past.data?.length ? (
        <>
          <AppText variant="title" style={{ marginTop: 8 }}>
            Past polls
          </AppText>
          {past.data.map((poll) => (
            <PollCard key={poll.id} poll={poll} />
          ))}
        </>
      ) : null}
    </ScrollView>
  );
}

export default function PollsScreen() {
  return (
    <FeatureGate feature="polls">
      <Stack.Screen options={{ title: 'Polls' }} />
      <Polls />
    </FeatureGate>
  );
}
