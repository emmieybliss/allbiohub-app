import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, useWindowDimensions, View } from 'react-native';
import { paths } from '@/lib/deepLinks';
import { relativeDate } from '@/lib/text';
import type { Article } from '@/models/types';
import { useBookmarks } from '@/stores/bookmarks';
import { radius, usePalette } from '@/theme';
import { AppImage } from './AppImage';
import { AppText, IconButton } from './ui';
import * as Haptics from 'expo-haptics';

function open(a: Article) {
  router.push(paths.article(a.id) as never);
}

function Meta({ article, light }: { article: Article; light?: boolean }) {
  const parts = [article.author?.name, relativeDate(article.publishedAt), article.readingMinutes ? `${article.readingMinutes} min read` : undefined].filter(
    Boolean,
  );
  return (
    <AppText variant="caption" color={light ? 'rgba(255,255,255,0.85)' : 'subtle'} numberOfLines={1}>
      {parts.join(' · ')}
    </AppText>
  );
}

export function SaveButton({ article, color }: { article: Article; color?: string }) {
  const saved = useBookmarks((s) => s.items.some((a) => a.id === article.id));
  const toggle = useBookmarks((s) => s.toggle);
  const p = usePalette();
  return (
    <IconButton
      icon={saved ? 'bookmark' : 'bookmark-outline'}
      label={saved ? 'Remove from saved' : 'Save story'}
      color={color ?? (saved ? p.accentText : p.subtle)}
      size={20}
      onPress={() => {
        toggle(article);
        Haptics.selectionAsync().catch(() => {});
      }}
    />
  );
}

/** Large lead card with the image behind the headline. */
export function HeroCard({ article }: { article: Article }) {
  const { width } = useWindowDimensions();
  const w = width - 32;
  return (
    <Pressable onPress={() => open(article)} accessibilityRole="button" accessibilityLabel={article.title} style={{ marginHorizontal: 16 }}>
      <View style={[styles.hero, { height: w * 0.75 }]}>
        <AppImage image={article.image} width={w} style={StyleSheet.absoluteFill} />
        <View style={styles.heroScrim} />
        <View style={styles.heroText}>
          {article.categories[0] ? (
            <AppText variant="overline" color="#FFB28A">
              {article.categories[0].name}
            </AppText>
          ) : null}
          <AppText variant="headline" color="#FFFFFF" numberOfLines={3}>
            {article.title}
          </AppText>
          <Meta article={article} light />
        </View>
      </View>
    </Pressable>
  );
}

/** Image on the left, headline on the right. */
export function RowCard({ article, showSave = true }: { article: Article; showSave?: boolean }) {
  return (
    <Pressable
      onPress={() => open(article)}
      accessibilityRole="button"
      accessibilityLabel={article.title}
      style={({ pressed }) => [styles.row, { opacity: pressed ? 0.8 : 1 }]}
    >
      <AppImage image={article.image} width={112} style={styles.rowImage} rounded={radius.md} allowCropped />
      <View style={{ flex: 1, gap: 4 }}>
        {article.categories[0] ? (
          <AppText variant="overline" color="accent" numberOfLines={1}>
            {article.categories[0].name}
          </AppText>
        ) : null}
        <AppText variant="subtitle" numberOfLines={3}>
          {article.title}
        </AppText>
        <Meta article={article} />
      </View>
      {showSave ? <SaveButton article={article} /> : null}
    </Pressable>
  );
}

/** Narrow card for horizontal rails. */
export function RailCard({ article }: { article: Article }) {
  const w = 220;
  return (
    <Pressable onPress={() => open(article)} accessibilityRole="button" accessibilityLabel={article.title} style={{ width: w, gap: 8 }}>
      <AppImage image={article.image} width={w} style={{ width: w, height: w * 0.62 }} rounded={radius.md} />
      <AppText variant="subtitle" numberOfLines={3}>
        {article.title}
      </AppText>
      <Meta article={article} />
    </Pressable>
  );
}

export function ReadingTime({ minutes }: { minutes?: number }) {
  const p = usePalette();
  if (!minutes) return null;
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
      <Ionicons name="time-outline" size={14} color={p.subtle} />
      <AppText variant="caption" color="subtle">
        {minutes} min read
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { borderRadius: radius.xl, overflow: 'hidden', justifyContent: 'flex-end' },
  heroScrim: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(0,0,0,0.45)' },
  heroText: { padding: 18, gap: 6 },
  row: { flexDirection: 'row', gap: 12, paddingHorizontal: 16, paddingVertical: 10, alignItems: 'flex-start' },
  rowImage: { width: 112, height: 84 },
});
