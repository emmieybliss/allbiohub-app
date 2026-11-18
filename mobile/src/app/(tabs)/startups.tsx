import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Linking, Pressable, RefreshControl, ScrollView, StyleSheet, TextInput, View } from 'react-native';
import { isDirectoryUnavailable, refreshAll, useStartupFilters, useStartupPage, useStartupRail } from '@/api/queries';
import { TabHeader } from '@/components/Screen';
import { StartupRailCard, StartupRow } from '@/components/StartupCards';
import { AppText, Button, ErrorView, SectionHeader, SkeletonBox, StateView } from '@/components/ui';
import { sitePage } from '@/config/env';
import { DirectoryUnavailable } from '@/features/startups/DirectoryUnavailable';
import { queryToParams } from '@/features/startups/params';
import { SortPicker } from '@/features/startups/SortPicker';
import { openLink } from '@/lib/links';
import { compactNumber } from '@/lib/text';
import type { FilterOption, Page, Startup, StartupQuery, StartupSort } from '@/models/types';
import { hasMore } from '@/models/types';
import { brand, fonts, radius, usePalette } from '@/theme';

function openDirectory(q: StartupQuery) {
  router.push({ pathname: '/directory', params: queryToParams(q) });
}

/** "Discover African Startups", the search box and the two website actions. */
function Hero() {
  const [text, setText] = useState('');
  return (
    <View style={styles.hero}>
      <AppText variant="headline" color="#FFFFFF" accessibilityRole="header">
        Discover African Startups
      </AppText>
      <AppText color="rgba(255,255,255,0.8)" style={{ marginTop: 6 }}>
        Explore startups, founders, products and emerging companies across Africa.
      </AppText>
      <View style={styles.search}>
        <Ionicons name="search" size={18} color="#55525E" />
        <TextInput
          value={text}
          onChangeText={setText}
          placeholder="Search startups"
          placeholderTextColor="#77747F"
          returnKeyType="search"
          accessibilityLabel="Search startups"
          onSubmitEditing={() => openDirectory({ search: text.trim() || undefined })}
          style={{ flex: 1, fontFamily: fonts.body, fontSize: 16, color: '#16141A', paddingVertical: 12 }}
        />
      </View>
      <View style={styles.heroButtons}>
        <Button kind="onDark" label="List Your Startup" onPress={() => openLink(sitePage('list-your-startup/'))} />
        <Button kind="onDarkOutlined" label="Claim Your Profile" onPress={() => openLink(sitePage('claim-startup/'))} />
      </View>
    </View>
  );
}

function total(page?: Page<Startup>): number | undefined {
  if (!page) return undefined;
  return page.total ?? (hasMore(page) ? undefined : page.items.length);
}

/** Startups, Verified, Countries, Industries: counts from the API only. */
function Stats({ countries, industries }: { countries: number; industries: number }) {
  const p = usePalette();
  const all = useStartupPage({});
  const verified = useStartupPage({ verified: true });
  const stats: [string, number | undefined][] = [
    ['Startups', total(all.data)],
    ['Verified', total(verified.data)],
    ['Countries', countries],
    ['Industries', industries],
  ];
  return (
    <View style={styles.stats}>
      {stats.map(([label, value]) => (
        <View key={label} style={[styles.stat, { backgroundColor: p.card, borderColor: p.border }]} accessible accessibilityLabel={`${label}: ${value ?? 'loading'}`}>
          <AppText variant="title" color="accent">
            {value === undefined ? '–' : compactNumber(value)}
          </AppText>
          <AppText variant="caption" color="muted" numberOfLines={1}>
            {label}
          </AppText>
        </View>
      ))}
    </View>
  );
}

function FeaturedRail() {
  const q = useStartupRail({ featured: true });
  if (!q.data?.length) return null;
  return (
    <View>
      <SectionHeader title="Featured startups" action={{ label: 'See all', onPress: () => openDirectory({ featured: true, sort: 'featured' }) }} />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 16, gap: 12 }}>
        {q.data.map((s) => (
          <StartupRailCard key={s.id} startup={s} />
        ))}
      </ScrollView>
    </View>
  );
}

function BrowseBy({ title, options, toQuery }: { title: string; options: FilterOption[]; toQuery: (v: string) => StartupQuery }) {
  const p = usePalette();
  if (!options.length) return null;
  return (
    <View>
      <SectionHeader title={title} />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 16, gap: 10 }}>
        {options.map((o) => (
          <Pressable
            key={o.value}
            onPress={() => openDirectory(toQuery(o.value))}
            accessibilityRole="button"
            accessibilityLabel={o.count !== undefined ? `${o.label}, ${o.count} startups` : o.label}
            style={({ pressed }) => [styles.browse, { backgroundColor: p.card, borderColor: p.border, opacity: pressed ? 0.8 : 1 }]}
          >
            <AppText variant="label" numberOfLines={2}>
              {o.label}
            </AppText>
            {o.count !== undefined ? (
              <AppText variant="caption" color="subtle">
                {o.count} {o.count === 1 ? 'startup' : 'startups'}
              </AppText>
            ) : null}
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}

/** The sortable list, as on the website. */
function AllStartups() {
  const [sort, setSort] = useState<StartupSort>('newest');
  const page = useStartupPage({ sort });
  const count = total(page.data);
  return (
    <View>
      <SectionHeader title="All startups" action={{ label: 'Filters', onPress: () => openDirectory({ sort }) }} />
      <SortPicker value={sort} onChange={setSort} />
      <View style={{ gap: 10, marginTop: 12 }}>
        {page.isPending ? (
          [0, 1, 2].map((i) => <SkeletonBox key={i} height={96} radius={16} style={{ marginHorizontal: 16, width: undefined }} />)
        ) : page.isError ? (
          <ErrorView error={page.error} onRetry={() => page.refetch()} />
        ) : page.data.items.length ? (
          page.data.items.map((s) => <StartupRow key={s.id} startup={s} />)
        ) : (
          <StateView
            icon="rocket-outline"
            title="No startups to show yet"
            body="You can browse them on allbiohub.com."
            action={{ label: 'Browse startups on allbiohub.com', onPress: () => Linking.openURL(sitePage('startups/')) }}
          />
        )}
      </View>
      {page.data?.items.length ? (
        <View style={{ paddingHorizontal: 16, marginTop: 12 }}>
          <Button kind="outlined" label={count ? `See all ${compactNumber(count)}` : 'See all startups'} onPress={() => openDirectory({ sort })} />
        </View>
      ) : null}
    </View>
  );
}

function BuildingCta() {
  const p = usePalette();
  return (
    <View style={[styles.cta, { backgroundColor: p.accentSoft }]}>
      <AppText variant="title">Building something in Africa?</AppText>
      <AppText color="muted">Add your startup to the AllBioHub directory, claim your profile, or get verified.</AppText>
      <View style={styles.heroButtons}>
        <Button label="List Your Startup" onPress={() => openLink(sitePage('list-your-startup/'))} />
        <Button kind="outlined" label="Claim Your Startup" onPress={() => openLink(sitePage('claim-startup/'))} />
        <Button kind="text" label="Get Verified →" onPress={() => openLink(sitePage('startup-pricing/'))} />
      </View>
    </View>
  );
}

export default function StartupsScreen() {
  const p = usePalette();
  const filters = useStartupFilters();
  const [refreshing, setRefreshing] = useState(false);

  let body;
  if (filters.isPending) {
    body = (
      <View style={{ padding: 16, gap: 16 }}>
        <SkeletonBox height={260} radius={20} />
        <SkeletonBox height={72} radius={14} />
        <SkeletonBox height={200} radius={16} />
      </View>
    );
  } else if (filters.isError && isDirectoryUnavailable(filters.error)) {
    body = <DirectoryUnavailable />;
  } else if (filters.isError) {
    body = <ErrorView error={filters.error} onRetry={() => filters.refetch()} />;
  } else {
    const f = filters.data;
    body = (
      <>
        <Hero />
        <Stats countries={f.countries.length} industries={f.industries.length} />
        <FeaturedRail />
        <BrowseBy title="Browse by industry" options={f.industries} toQuery={(v) => ({ industry: v })} />
        <AllStartups />
        <BrowseBy title="Browse by country" options={f.countries} toQuery={(v) => ({ country: v })} />
        <BuildingCta />
      </>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="Startups" />
      <ScrollView
        contentContainerStyle={{ paddingBottom: 32, flexGrow: 1 }}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            tintColor={p.accentText}
            colors={[p.accent]}
            onRefresh={async () => {
              setRefreshing(true);
              await refreshAll(filters.refetch);
              setRefreshing(false);
            }}
          />
        }
      >
        {body}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { marginHorizontal: 16, marginTop: 4, padding: 20, paddingTop: 24, borderRadius: radius.xl, backgroundColor: brand.purpleDeep, overflow: 'hidden' },
  search: { flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: '#FFFFFF', borderRadius: 14, paddingHorizontal: 12, marginTop: 18 },
  heroButtons: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginTop: 16 },
  stats: { flexDirection: 'row', gap: 8, paddingHorizontal: 16, marginTop: 16 },
  stat: { flex: 1, alignItems: 'center', paddingVertical: 12, borderRadius: radius.md, borderWidth: StyleSheet.hairlineWidth },
  browse: { width: 150, minHeight: 72, padding: 12, borderRadius: radius.md, borderWidth: StyleSheet.hairlineWidth, justifyContent: 'space-between', gap: 4 },
  cta: { margin: 16, marginTop: 28, padding: 20, borderRadius: radius.xl, gap: 6 },
});
