import { router } from 'expo-router';
import { useState } from 'react';
import { FlatList, type NativeScrollEvent, RefreshControl, ScrollView, useWindowDimensions, View } from 'react-native';
import { flatten, refreshAll, useCategories, useCategoryPreview, useHomeFeed, useStartupRail, useStoryFeed } from '@/api/queries';
import { HeroCard, RailCard, RowCard } from '@/components/ArticleCards';
import { TabHeader } from '@/components/Screen';
import { StartupRailCard } from '@/components/StartupCards';
import { Button, ErrorView, ListSkeleton, OfflineBanner, SectionHeader, SkeletonBox, StateView } from '@/components/ui';
import { paths } from '@/lib/deepLinks';
import type { Term } from '@/models/types';
import { usePalette } from '@/theme';

function FeaturedCarousel({ articles }: { articles: Parameters<typeof HeroCard>[0]['article'][] }) {
  const { width } = useWindowDimensions();
  if (!articles.length) return null;
  return (
    <FlatList
      horizontal
      data={articles}
      keyExtractor={(a) => String(a.id)}
      renderItem={({ item }) => (
        <View style={{ width: articles.length > 1 ? width * 0.9 : width, marginRight: articles.length > 1 ? -16 : 0 }}>
          <HeroCard article={item} />
        </View>
      )}
      showsHorizontalScrollIndicator={false}
      snapToInterval={width * 0.9 - 16}
      decelerationRate="fast"
      contentContainerStyle={{ paddingTop: 8 }}
    />
  );
}

function CategoryRail({ category }: { category: Term }) {
  const q = useCategoryPreview(category.id);
  // A rail that fails or is empty is left out; Home stays usable.
  if (q.isError || (q.data && !q.data.length)) return null;
  return (
    <View>
      <SectionHeader title={category.name} action={{ label: 'See all', onPress: () => router.push(paths.category(category.slug) as never) }} />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 16, gap: 14 }}>
        {q.data
          ? q.data.map((a) => <RailCard key={a.id} article={a} />)
          : [0, 1, 2].map((i) => (
              <View key={i} style={{ width: 220, gap: 8 }}>
                <SkeletonBox height={136} radius={12} />
                <SkeletonBox height={14} />
                <SkeletonBox height={14} width="70%" />
              </View>
            ))}
      </ScrollView>
    </View>
  );
}

function StartupsSection() {
  const q = useStartupRail({ sort: 'newest' });
  // Hidden until the startup directory add-on is switched on.
  if (!q.data?.length) return null;
  return (
    <View>
      <SectionHeader
        title="Explore African startups"
        subtitle="From the AllBioHub startup directory"
        action={{ label: 'See all', onPress: () => router.push('/startups') }}
      />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 16, gap: 12 }}>
        {q.data.map((s) => (
          <StartupRailCard key={s.id} startup={s} />
        ))}
      </ScrollView>
    </View>
  );
}

export default function HomeScreen() {
  const p = usePalette();
  const feed = useHomeFeed();
  const categories = useCategories();
  const [showMore, setShowMore] = useState(false);
  // Continues after the first page the top of Home already shows.
  const more = useStoryFeed('home-more', { skip: 1 }, showMore);
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = async () => {
    setRefreshing(true);
    await refreshAll(feed.refetch, categories.refetch);
    setRefreshing(false);
  };

  const cats = categories.data ?? [];
  const latest = feed.data?.latest ?? [];
  const top = latest.slice(0, 5);
  const rest = latest.slice(5);
  const shown = new Set([...(feed.data?.featured ?? []), ...latest].map((a) => a.id));
  const moreItems = flatten(more.data?.pages).filter((a) => !shown.has(a.id));

  // Infinite list: the next page loads as the bottom comes into view.
  const onScroll = ({ nativeEvent: e }: { nativeEvent: NativeScrollEvent }) => {
    if (e.layoutMeasurement.height + e.contentOffset.y < e.contentSize.height - 600) return;
    if (!feed.data || more.isFetching || more.isError) return;
    if (!showMore) setShowMore(true);
    else if (more.hasNextPage) more.fetchNextPage();
  };

  let body;
  if (feed.isPending) {
    body = (
      <View style={{ padding: 16, gap: 16 }}>
        <SkeletonBox height={260} radius={20} />
        <ListSkeleton rows={4} />
      </View>
    );
  } else if (feed.isError) {
    body = <ErrorView error={feed.error} onRetry={() => feed.refetch()} />;
  } else if (!feed.data.featured.length && !latest.length) {
    body = <StateView title="No stories yet" body="New stories from AllBioHub will show up here." action={{ label: 'Refresh', onPress: onRefresh }} />;
  } else {
    body = (
      <>
        {feed.data.stale ? <OfflineBanner /> : null}
        <FeaturedCarousel articles={feed.data.featured} />
        <SectionHeader title="Latest stories" />
        {top.map((a) => (
          <RowCard key={a.id} article={a} />
        ))}
        {cats.slice(0, 2).map((c) => (
          <CategoryRail key={c.id} category={c} />
        ))}
        <StartupsSection />
        {/* Every other category, so small ones like Women in Tech still show. */}
        {cats.slice(2).map((c) => (
          <CategoryRail key={c.id} category={c} />
        ))}
        {rest.length ? (
          <>
            <SectionHeader title="More to read" />
            {rest.map((a) => (
              <RowCard key={a.id} article={a} />
            ))}
          </>
        ) : null}
        <SectionHeader title="Keep reading" />
        {moreItems.map((a) => (
          <RowCard key={a.id} article={a} />
        ))}
        <View style={{ padding: 16 }}>
          {more.isFetching ? (
            <ListSkeleton rows={2} />
          ) : more.isError ? (
            <ErrorView error={more.error} onRetry={() => more.fetchNextPage()} />
          ) : !showMore || more.hasNextPage ? (
            <Button
              kind="outlined"
              label="Load more stories"
              onPress={() => (showMore ? more.fetchNextPage() : setShowMore(true))}
            />
          ) : null}
        </View>
      </>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="AllBioHub" logo />
      <ScrollView
        contentContainerStyle={{ paddingBottom: 32, flexGrow: 1 }}
        onScroll={onScroll}
        scrollEventThrottle={200}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={p.accentText} colors={[p.accent]} />}
      >
        {body}
      </ScrollView>
    </View>
  );
}

