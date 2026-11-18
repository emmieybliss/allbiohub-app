import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, View } from 'react-native';
import { refreshAll, useCategories, usePopularTags, useStartupFilters } from '@/api/queries';
import { TabHeader } from '@/components/Screen';
import { AppText, Chip, ErrorView, SectionHeader, SkeletonBox } from '@/components/ui';
import { paths } from '@/lib/deepLinks';
import { compactNumber } from '@/lib/text';
import { radius, usePalette } from '@/theme';

export default function DiscoverScreen() {
  const p = usePalette();
  const categories = useCategories();
  const tags = usePopularTags();
  const filters = useStartupFilters();
  const [refreshing, setRefreshing] = useState(false);
  const industries = filters.data?.industries.slice(0, 12) ?? [];

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="Discover" />
      <ScrollView
        contentContainerStyle={{ paddingBottom: 32 }}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            tintColor={p.accentText}
            colors={[p.accent]}
            onRefresh={async () => {
              setRefreshing(true);
              await refreshAll(categories.refetch, tags.refetch, filters.refetch);
              setRefreshing(false);
            }}
          />
        }
      >
        <SectionHeader title="Explore by topic" subtitle="Every section on AllBioHub" />
        {categories.isError ? (
          <ErrorView error={categories.error} onRetry={() => categories.refetch()} />
        ) : (
          <View style={styles.grid}>
            {(categories.data ?? Array.from({ length: 6 }, () => null)).map((c, i) =>
              c ? (
                <Pressable
                  key={c.id}
                  onPress={() => router.push(paths.category(c.slug) as never)}
                  accessibilityRole="button"
                  accessibilityLabel={`${c.name}, ${c.count} stories`}
                  style={({ pressed }) => [styles.tile, { backgroundColor: i % 3 === 0 ? p.accentSoft : p.card, borderColor: p.border, opacity: pressed ? 0.8 : 1 }]}
                >
                  <AppText variant="subtitle" numberOfLines={2}>
                    {c.name}
                  </AppText>
                  <AppText variant="caption" color="muted">
                    {compactNumber(c.count)} {c.count === 1 ? 'story' : 'stories'}
                  </AppText>
                </Pressable>
              ) : (
                <View key={i} style={styles.tileSkeleton}>
                  <SkeletonBox height={84} radius={16} />
                </View>
              ),
            )}
          </View>
        )}

        {tags.data?.length ? (
          <>
            <SectionHeader title="Popular topics" />
            <View style={styles.chips}>
              {tags.data.map((t) => (
                <Chip key={t.id} label={`#${t.name}`} onPress={() => router.push(paths.tag(t.slug) as never)} />
              ))}
            </View>
          </>
        ) : null}

        {industries.length ? (
          <>
            <SectionHeader title="Startups by industry" action={{ label: 'Directory', onPress: () => router.push(paths.directory as never) }} />
            <View style={styles.chips}>
              {industries.map((o) => (
                <Pressable
                  key={o.value}
                  onPress={() => router.push({ pathname: '/directory', params: { industry: o.value } })}
                  accessibilityRole="button"
                  style={({ pressed }) => [styles.industry, { borderColor: p.border, backgroundColor: p.card, opacity: pressed ? 0.8 : 1 }]}
                >
                  <Ionicons name="rocket-outline" size={14} color={p.accentText} />
                  <AppText variant="label">{o.label}</AppText>
                  {o.count !== undefined ? (
                    <AppText variant="caption" color="subtle">
                      {o.count}
                    </AppText>
                  ) : null}
                </Pressable>
              ))}
            </View>
          </>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 12, gap: 8 },
  tile: { width: '48%', flexGrow: 1, minHeight: 84, padding: 14, borderRadius: radius.lg, borderWidth: StyleSheet.hairlineWidth, justifyContent: 'space-between', gap: 6 },
  tileSkeleton: { width: '48%', flexGrow: 1 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingHorizontal: 16 },
  industry: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: 12, minHeight: 36 },
});
