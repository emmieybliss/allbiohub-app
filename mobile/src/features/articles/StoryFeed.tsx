import { Stack } from 'expo-router';
import type { ReactElement } from 'react';
import { FlatList, View } from 'react-native';
import { flatten, refreshAll, useStoryFeed } from '@/api/queries';
import { RowCard } from '@/components/ArticleCards';
import { ErrorView, ListSkeleton, OfflineBanner, StateView } from '@/components/ui';
import { usePalette } from '@/theme';

/** Infinite list of stories for a category, tag or author. */
export function StoryFeed({
  title,
  feedKey,
  kind,
  header,
}: {
  title: string;
  feedKey: string;
  kind: { categoryId?: number; tagId?: number; authorId?: number } | undefined;
  header?: ReactElement | null;
}) {
  const p = usePalette();
  const feed = useStoryFeed(feedKey, kind ?? {}, kind !== undefined);
  const items = flatten(feed.data?.pages);
  const stale = feed.data?.pages.some((pg) => pg.stale);

  let empty;
  if (!kind || feed.isPending) empty = <ListSkeleton rows={6} />;
  else if (feed.isError) empty = <ErrorView error={feed.error} onRetry={() => feed.refetch()} />;
  else empty = <StateView title="Nothing to show" body="There are no stories here yet." />;

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <Stack.Screen options={{ title }} />
      <FlatList
        data={items}
        keyExtractor={(a) => String(a.id)}
        renderItem={({ item }) => <RowCard article={item} />}
        ListHeaderComponent={
          <>
            {header}
            {stale ? <OfflineBanner /> : null}
          </>
        }
        ListEmptyComponent={empty}
        contentContainerStyle={{ paddingBottom: 32, flexGrow: 1 }}
        onEndReachedThreshold={0.5}
        onEndReached={() => feed.hasNextPage && !feed.isFetchingNextPage && !feed.isError && feed.fetchNextPage()}
        ListFooterComponent={
          feed.isFetchingNextPage ? <ListSkeleton rows={1} /> : feed.isFetchNextPageError ? <ErrorView error={feed.error} onRetry={() => feed.fetchNextPage()} /> : undefined
        }
        refreshing={feed.isRefetching && !feed.isFetchingNextPage}
        onRefresh={() => refreshAll(feed.refetch)}
      />
    </View>
  );
}
