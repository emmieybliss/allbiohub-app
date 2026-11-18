import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { useState } from 'react';
import { FlatList, View } from 'react-native';
import { router } from 'expo-router';
import { RowCard } from '@/components/ArticleCards';
import { Row, TabHeader } from '@/components/Screen';
import { AppText, Chip, Divider, IconButton, StateView } from '@/components/ui';
import type { SavedEntity, SavedKind } from '@/features/community/models';
import { savedKey } from '@/features/community/models';
import { useSavedEntities } from '@/features/community/store';
import { paths } from '@/lib/deepLinks';
import type { Article } from '@/models/types';
import { useBookmarks } from '@/stores/bookmarks';
import { radius, usePalette } from '@/theme';

type Tab = 'stories' | SavedKind;

function openEntity(e: SavedEntity) {
  if (e.kind === 'startup') router.push(paths.startup(e.id) as never);
  else router.push({ pathname: '/founder/[slug]', params: { slug: e.id, name: e.title, url: e.url } } as never);
}

/** A saved startup or founder: picture or icon, name, line of detail, and remove. */
function EntityRow({ entity }: { entity: SavedEntity }) {
  const p = usePalette();
  const toggle = useSavedEntities((s) => s.toggle);
  return (
    <View>
      <Row onPress={() => openEntity(entity)} label={entity.title}>
        {entity.image ? (
          <Image source={entity.image} style={{ width: 44, height: 44, borderRadius: entity.kind === 'founder' ? 22 : radius.sm, backgroundColor: p.card }} contentFit="cover" />
        ) : (
          <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name={entity.kind === 'founder' ? 'person-outline' : 'rocket-outline'} size={20} color={p.accentText} />
          </View>
        )}
        <View style={{ flex: 1 }}>
          <AppText variant="label" numberOfLines={2}>
            {entity.title}
          </AppText>
          {entity.subtitle ? (
            <AppText variant="caption" color="muted" numberOfLines={1}>
              {entity.subtitle}
            </AppText>
          ) : null}
        </View>
        <IconButton icon="trash-outline" label={`Remove ${entity.title} from saved`} color={p.subtle} onPress={() => toggle(entity)} />
      </Row>
      <Divider />
    </View>
  );
}

/**
 * Saved stories live on this phone and are readable offline (the reader caches
 * them). Saved startups and founders get their own tabs once there are any.
 */
export default function SavedScreen() {
  const p = usePalette();
  const items = useBookmarks((s) => s.items);
  const remove = useBookmarks((s) => s.remove);
  const restore = useBookmarks((s) => s.restore);
  const [undo, setUndo] = useState<{ article: Article; index: number } | null>(null);
  const entities = useSavedEntities((s) => s.items);
  const [tab, setTab] = useState<Tab>('stories');
  const startups = entities.filter((e) => e.kind === 'startup');
  const founders = entities.filter((e) => e.kind === 'founder');
  const tabs: [Tab, string, number][] = [
    ['stories', 'Stories', items.length],
    ['startup', 'Startups', startups.length],
    ['founder', 'Founders', founders.length],
  ];
  // A tab emptied elsewhere falls back to stories.
  const current: Tab = tab !== 'stories' && !(tab === 'startup' ? startups : founders).length ? 'stories' : tab;

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="Saved" />
      {entities.length ? (
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingHorizontal: 16, paddingBottom: 8 }}>
          {tabs
            .filter(([key, , count]) => key === 'stories' || count > 0)
            .map(([key, label, count]) => (
              <Chip key={key} label={`${label} ${count}`} selected={current === key} onPress={() => setTab(key)} />
            ))}
        </View>
      ) : null}
      {current !== 'stories' ? (
        <FlatList
          data={current === 'startup' ? startups : founders}
          keyExtractor={savedKey}
          renderItem={({ item }) => <EntityRow entity={item} />}
          contentContainerStyle={{ paddingBottom: 32 }}
        />
      ) : (
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
      )}
      {undo && current === 'stories' ? (
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
