import { Ionicons } from '@expo/vector-icons';
import { Stack, useLocalSearchParams } from 'expo-router';
import { useMemo, useState } from 'react';
import { FlatList, Modal, Pressable, ScrollView, StyleSheet, Switch, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { activeFilterCount } from '@/api/startups';
import { flatten, isDirectoryUnavailable, useStartupDirectory, useStartupFilters } from '@/api/queries';
import { StartupRow } from '@/components/StartupCards';
import { AppText, Button, Chip, ErrorView, IconButton, ListSkeleton, StateView } from '@/components/ui';
import { DirectoryUnavailable } from '@/features/startups/DirectoryUnavailable';
import { type DirectoryParams, paramsToQuery } from '@/features/startups/params';
import { SortPicker } from '@/features/startups/SortPicker';
import type { FilterOption, StartupFilterOptions, StartupQuery } from '@/models/types';
import { fonts, radius, usePalette } from '@/theme';

export default function DirectoryScreen() {
  const p = usePalette();
  const params = useLocalSearchParams<DirectoryParams>();
  const initial = useMemo(() => paramsToQuery(params), []); // eslint-disable-line react-hooks/exhaustive-deps
  const [query, setQuery] = useState<StartupQuery>(initial);
  const [searchText, setSearchText] = useState(initial.search ?? '');
  const [showFilters, setShowFilters] = useState(false);
  const list = useStartupDirectory(query);
  const filters = useStartupFilters();
  const items = flatten(list.data?.pages);
  const total = list.data?.pages[0]?.total;
  const active = activeFilterCount(query);

  const header = (
    <View style={{ gap: 12, paddingTop: 8, paddingBottom: 12 }}>
      <View style={{ flexDirection: 'row', gap: 8, paddingHorizontal: 16 }}>
        <View style={[styles.search, { backgroundColor: p.card, borderColor: p.border }]}>
          <Ionicons name="search" size={18} color={p.subtle} />
          <TextInput
            value={searchText}
            onChangeText={setSearchText}
            placeholder="Search startups"
            placeholderTextColor={p.subtle}
            returnKeyType="search"
            onSubmitEditing={() => setQuery({ ...query, search: searchText.trim() || undefined })}
            accessibilityLabel="Search startups"
            style={{ flex: 1, fontFamily: fonts.body, fontSize: 16, color: p.text, paddingVertical: 10 }}
          />
          {searchText ? (
            <IconButton icon="close-circle" size={18} color={p.subtle} label="Clear search" onPress={() => (setSearchText(''), setQuery({ ...query, search: undefined }))} />
          ) : null}
        </View>
        <Pressable
          onPress={() => setShowFilters(true)}
          accessibilityRole="button"
          accessibilityLabel={active ? `Filters, ${active} on` : 'Filters'}
          style={[styles.filterButton, { borderColor: active ? p.accent : p.border, backgroundColor: active ? p.accentSoft : p.card }]}
        >
          <Ionicons name="options-outline" size={18} color={p.accentText} />
          {active ? (
            <AppText variant="label" color="accent">
              {active}
            </AppText>
          ) : null}
        </Pressable>
      </View>
      <SortPicker value={query.sort ?? 'newest'} onChange={(sort) => setQuery({ ...query, sort })} />
      {total !== undefined ? (
        <AppText variant="caption" color="muted" style={{ paddingHorizontal: 16 }}>
          {total === 1 ? '1 startup' : `${total} startups`}
        </AppText>
      ) : null}
    </View>
  );

  let empty;
  if (list.isPending) empty = <ListSkeleton rows={5} />;
  else if (list.isError && isDirectoryUnavailable(list.error)) empty = <DirectoryUnavailable />;
  else if (list.isError) empty = <ErrorView error={list.error} onRetry={() => list.refetch()} />;
  else
    empty = (
      <StateView
        icon="search-outline"
        title="No startups match your filters."
        action={active || query.search ? { label: 'Clear filters', onPress: () => (setSearchText(''), setQuery({ sort: query.sort })) } : undefined}
      />
    );

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <Stack.Screen options={{ title: 'Startup directory' }} />
      <FlatList
        data={items}
        keyExtractor={(s) => String(s.id)}
        renderItem={({ item }) => <StartupRow startup={item} />}
        ItemSeparatorComponent={() => <View style={{ height: 10 }} />}
        ListHeaderComponent={header}
        ListEmptyComponent={empty}
        contentContainerStyle={{ paddingBottom: 32, flexGrow: 1 }}
        onEndReachedThreshold={0.5}
        onEndReached={() => list.hasNextPage && !list.isFetchingNextPage && !list.isError && list.fetchNextPage()}
        ListFooterComponent={
          list.isFetchingNextPage ? (
            <ListSkeleton rows={1} />
          ) : list.isFetchNextPageError ? (
            <ErrorView error={list.error} onRetry={() => list.fetchNextPage()} />
          ) : undefined
        }
        refreshing={list.isRefetching && !list.isFetchingNextPage}
        onRefresh={() => list.refetch()}
      />
      {filters.data ? (
        <FilterSheet visible={showFilters} options={filters.data} query={query} onClose={() => setShowFilters(false)} onApply={(q) => (setQuery(q), setShowFilters(false))} />
      ) : null}
    </View>
  );
}

type Key = 'industry' | 'country' | 'stage' | 'funding' | 'businessModel' | 'employees';

function FilterSheet({
  visible,
  options,
  query,
  onClose,
  onApply,
}: {
  visible: boolean;
  options: StartupFilterOptions;
  query: StartupQuery;
  onClose: () => void;
  onApply: (q: StartupQuery) => void;
}) {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const [draft, setDraft] = useState(query);
  const [cityText, setCityText] = useState(query.city ?? '');
  const groups: [string, Key, FilterOption[]][] = [
    ['Industry', 'industry', options.industries],
    ['Country', 'country', options.countries],
    ['Stage', 'stage', options.stages],
    ['Funding', 'funding', options.fundings],
    ['Business model', 'businessModel', options.businessModels],
    ['Team size', 'employees', options.employeeRanges],
  ];
  const toggles: [string, 'verified' | 'claimed' | 'featured'][] = [
    ['AllBioHub verified only', 'verified'],
    ['Claimed profiles only', 'claimed'],
    ['Featured only', 'featured'],
  ];
  return (
    <Modal visible={visible} animationType="slide" onShow={() => (setDraft(query), setCityText(query.city ?? ''))} onRequestClose={onClose} presentationStyle="pageSheet">
      <View style={{ flex: 1, backgroundColor: p.background, paddingTop: 12 }}>
        <View style={styles.sheetHeader}>
          <IconButton icon="close" label="Close" onPress={onClose} />
          <AppText variant="title" style={{ flex: 1 }}>
            Filters
          </AppText>
          <Button kind="text" label="Reset" onPress={() => (setCityText(''), setDraft({ search: draft.search, sort: draft.sort }))} />
        </View>
        <ScrollView contentContainerStyle={{ padding: 16, gap: 20, paddingBottom: 24 }}>
          {groups
            .filter(([, , opts]) => opts.length)
            .map(([label, key, opts]) => (
              <View key={key} style={{ gap: 10 }}>
                <AppText variant="subtitle">{label}</AppText>
                <View style={styles.chips}>
                  {opts.map((o) => (
                    <Chip
                      key={o.value}
                      label={o.count !== undefined ? `${o.label} (${o.count})` : o.label}
                      selected={draft[key] === o.value}
                      onPress={() => setDraft({ ...draft, [key]: draft[key] === o.value ? undefined : o.value })}
                    />
                  ))}
                </View>
              </View>
            ))}
          <View style={{ gap: 10 }}>
            <AppText variant="subtitle">City</AppText>
            <TextInput
              value={cityText}
              onChangeText={setCityText}
              placeholder="Any city"
              placeholderTextColor={p.subtle}
              accessibilityLabel="City"
              style={[styles.input, { borderColor: p.border, color: p.text, backgroundColor: p.card }]}
            />
          </View>
          {toggles.map(([label, key]) => (
            <View key={key} style={styles.toggle}>
              <AppText style={{ flex: 1 }}>{label}</AppText>
              <Switch
                value={draft[key] === true}
                onValueChange={(v) => setDraft({ ...draft, [key]: v ? true : undefined })}
                trackColor={{ true: p.accent, false: p.border }}
                thumbColor="#FFFFFF"
                accessibilityLabel={label}
              />
            </View>
          ))}
        </ScrollView>
        <View style={{ padding: 16, paddingBottom: 16 + insets.bottom, borderTopWidth: StyleSheet.hairlineWidth, borderColor: p.border }}>
          <Button label="Show startups" onPress={() => onApply({ ...draft, city: cityText.trim() || undefined })} />
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  search: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 12 },
  filterButton: { flexDirection: 'row', alignItems: 'center', gap: 4, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 14, minHeight: 48 },
  sheetHeader: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, gap: 4 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  input: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 12, paddingVertical: 10, fontFamily: fonts.body, fontSize: 16 },
  toggle: { flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 48 },
});
