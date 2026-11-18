import { useState } from 'react';
import { FlatList, View } from 'react-native';
import { router } from 'expo-router';
import { RowCard } from '@/components/ArticleCards';
import { TabHeader } from '@/components/Screen';
import { AppText, IconButton, StateView } from '@/components/ui';
import type { Article } from '@/models/types';
import { useBookmarks } from '@/stores/bookmarks';
import { radius, usePalette } from '@/theme';

/** Saved stories live on this phone and are readable offline (the reader caches them). */
export default function SavedScreen() {
  const p = usePalette();
  const items = useBookmarks((s) => s.items);
  const remove = useBookmarks((s) => s.remove);
  const restore = useBookmarks((s) => s.restore);
  const [undo, setUndo] = useState<{ article: Article; index: number } | null>(null);

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="Saved" />
      <FlatList
        data={items}
        keyExtractor={(a) => String(a.id)}
        renderItem={({ item, index }) => (
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <View style={{ flex: 1 }}>
              <RowCard article={item} showSave={false} />
            </View>
            <IconButton
              icon="trash-outline"
              label={`Remove ${item.title} from saved`}
              color={p.subtle}
              onPress={() => {
                remove(item.id);
                setUndo({ article: item, index });
              }}
            />
          </View>
        )}
        ListEmptyComponent={
          <StateView
            icon="bookmark-outline"
            title="Nothing saved yet."
            body="Tap the bookmark on any story to read it later, even offline."
            action={{ label: 'Browse stories', onPress: () => router.navigate('/') }}
          />
        }
        contentContainerStyle={{ paddingBottom: 32, flexGrow: 1 }}
      />
      {undo ? (
        <View style={{ position: 'absolute', left: 16, right: 16, bottom: 16, flexDirection: 'row', alignItems: 'center', padding: 12, paddingLeft: 16, borderRadius: radius.md, backgroundColor: p.text }}>
          <AppText color={p.background} style={{ flex: 1 }}>
            Removed from saved
          </AppText>
          <AppText
            variant="label"
            color={p.dark ? '#4F3DAD' : '#B3A6FF'}
            accessibilityRole="button"
            onPress={() => (restore(undo.article, undo.index), setUndo(null))}
            style={{ padding: 8 }}
          >
            Undo
          </AppText>
          <IconButton icon="close" label="Dismiss" color={p.background} onPress={() => setUndo(null)} />
        </View>
      ) : null}
    </View>
  );
}
