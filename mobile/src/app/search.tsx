import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { FlatList, Keyboard, StyleSheet, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { flatten, useCategories, useSearch } from '@/api/queries';
import { RowCard } from '@/components/ArticleCards';
import { AppText, Chip, ErrorView, IconButton, ListSkeleton, StateView } from '@/components/ui';
import { paths } from '@/lib/deepLinks';
import { fonts, radius, usePalette } from '@/theme';
import AsyncStorage from '@react-native-async-storage/async-storage';

const RECENT_KEY = 'abh.recentSearches';

function useDebounced(value: string, ms = 350) {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return v;
}

function useRecent() {
  const [recent, setRecent] = useState<string[]>([]);
  useEffect(() => {
    AsyncStorage.getItem(RECENT_KEY)
      .then((r) => r && setRecent(JSON.parse(r)))
      .catch(() => {});
  }, []);
  const save = (next: string[]) => {
    setRecent(next);
    AsyncStorage.setItem(RECENT_KEY, JSON.stringify(next)).catch(() => {});
  };
  return {
    recent,
    add: (q: string) => save([q, ...recent.filter((r) => r.toLowerCase() !== q.toLowerCase())].slice(0, 8)),
    clear: () => save([]),
  };
}

export default function SearchScreen() {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const [text, setText] = useState('');
  const query = useDebounced(text.trim());
  const { stories, topics } = useSearch(query);
  const categories = useCategories();
  const { recent, add, clear } = useRecent();
  const items = flatten(stories.data?.pages);
  const total = stories.data?.pages[0]?.total;

  const idle = query.length < 2;

  return (
    <View style={{ flex: 1, backgroundColor: p.background, paddingTop: insets.top }}>
      <View style={styles.bar}>
        <IconButton icon="arrow-back" label="Back" onPress={() => router.back()} />
        <View style={[styles.input, { backgroundColor: p.card, borderColor: p.border }]}>
          <Ionicons name="search" size={18} color={p.subtle} />
          <TextInput
            autoFocus
            value={text}
            onChangeText={setText}
            placeholder="Search stories and topics"
            placeholderTextColor={p.subtle}
            returnKeyType="search"
            onSubmitEditing={() => text.trim().length >= 2 && add(text.trim())}
            accessibilityLabel="Search"
            style={{ flex: 1, fontFamily: fonts.body, fontSize: 16, color: p.text, paddingVertical: 10 }}
          />
          {text ? <IconButton icon="close-circle" size={18} color={p.subtle} label="Clear" onPress={() => setText('')} /> : null}
        </View>
      </View>
      {idle ? (
        <FlatList
          data={[]}
          renderItem={() => null}
          keyboardShouldPersistTaps="handled"
          ListHeaderComponent={
            <View style={{ padding: 16, gap: 20 }}>
              {recent.length ? (
                <View style={{ gap: 10 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <AppText variant="subtitle" style={{ flex: 1 }}>
                      Recent searches
                    </AppText>
                    <AppText variant="label" color="accent" onPress={clear} accessibilityRole="button">
                      Clear
                    </AppText>
                  </View>
                  <View style={styles.chips}>
                    {recent.map((r) => (
                      <Chip key={r} label={r} onPress={() => setText(r)} />
                    ))}
                  </View>
                </View>
              ) : null}
              {categories.data?.length ? (
                <View style={{ gap: 10 }}>
                  <AppText variant="subtitle">Browse topics</AppText>
                  <View style={styles.chips}>
                    {categories.data.map((c) => (
                      <Chip key={c.id} label={c.name} onPress={() => router.push(paths.category(c.slug) as never)} />
                    ))}
                  </View>
                </View>
              ) : null}
            </View>
          }
        />
      ) : (
        <FlatList
          data={items}
          keyExtractor={(a) => String(a.id)}
          renderItem={({ item }) => <RowCard article={item} />}
          keyboardShouldPersistTaps="handled"
          onScrollBeginDrag={Keyboard.dismiss}
          ListHeaderComponent={
            <View style={{ gap: 12, paddingVertical: 8 }}>
              {topics.data?.length ? (
                <View style={[styles.chips, { paddingHorizontal: 16 }]}>
                  {topics.data.map((t) => (
                    <Chip
                      key={`${t.kind}-${t.id}`}
                      label={t.kind === 'tag' ? `#${t.name}` : t.name}
                      onPress={() => (add(query), router.push((t.kind === 'tag' ? paths.tag(t.slug) : paths.category(t.slug)) as never))}
                    />
                  ))}
                </View>
              ) : null}
              {total !== undefined && items.length ? (
                <AppText variant="caption" color="muted" style={{ paddingHorizontal: 16 }}>
                  {total === 1 ? '1 story' : `${total} stories`}
                </AppText>
              ) : null}
            </View>
          }
          ListEmptyComponent={
            stories.isPending ? (
              <ListSkeleton rows={5} />
            ) : stories.isError ? (
              <ErrorView error={stories.error} onRetry={() => stories.refetch()} />
            ) : (
              <StateView icon="search-outline" title={`No stories for “${query}”`} body="Try another word, or browse the topics." />
            )
          }
          onEndReachedThreshold={0.5}
          onEndReached={() => stories.hasNextPage && !stories.isFetchingNextPage && stories.fetchNextPage()}
          ListFooterComponent={stories.isFetchingNextPage ? <ListSkeleton rows={1} /> : undefined}
          contentContainerStyle={{ paddingBottom: 32 + insets.bottom, flexGrow: 1 }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 8, paddingVertical: 8 },
  input: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: 14, marginRight: 8 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
});
