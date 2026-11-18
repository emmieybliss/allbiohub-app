import { Ionicons } from '@expo/vector-icons';
import { Stack, router } from 'expo-router';
import { useState } from 'react';
import { Modal, Pressable, RefreshControl, ScrollView, StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { UseQueryResult } from '@tanstack/react-query';
import { refreshAll, useRelated } from '@/api/queries';
import { RowCard, SaveButton } from '@/components/ArticleCards';
import { AppImage } from '@/components/AppImage';
import { AppText, Button, Chip, ErrorView, IconButton, SectionHeader, SkeletonBox } from '@/components/ui';
import { aspectRatio } from '@/lib/images';
import { paths } from '@/lib/deepLinks';
import { shareArticle } from '@/lib/share';
import { fullDate } from '@/lib/text';
import type { Article } from '@/models/types';
import { TEXT_SIZES, textScale, usePreferences } from '@/stores/preferences';
import { usePalette } from '@/theme';
import { ArticleCommunitySection } from '@/features/community/ArticleCommunity';
import { ArticleBody } from './ArticleBody';

function TextSizeSheet({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const size = usePreferences((s) => s.textSize);
  const setSize = usePreferences((s) => s.setTextSize);
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={onClose} accessibilityLabel="Close" />
      <View style={[styles.sheet, { backgroundColor: p.surface, paddingBottom: 20 + insets.bottom }]}>
        <AppText variant="title">Text size</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
          {TEXT_SIZES.map((t) => (
            <Chip key={t.key} label={t.label} selected={t.key === size} onPress={() => setSize(t.key)} />
          ))}
        </View>
        <Button label="Done" onPress={onClose} />
      </View>
    </Modal>
  );
}

function Related({ article }: { article: Article }) {
  const q = useRelated(article);
  if (!q.data?.length) return null;
  return (
    <View>
      <SectionHeader title="Related stories" />
      {q.data.map((a) => (
        <RowCard key={a.id} article={a} />
      ))}
    </View>
  );
}

/** The reader, shared by /article/[id] and /story/[slug] (links from the website). */
export function ArticleView({ query }: { query: UseQueryResult<Article> }) {
  const p = usePalette();
  const { width } = useWindowDimensions();
  const scale = textScale(usePreferences((s) => s.textSize));
  const [sizeSheet, setSizeSheet] = useState(false);
  const a = query.data;

  if (query.isPending) {
    return (
      <View style={{ padding: 20, gap: 14 }}>
        <SkeletonBox height={12} width="30%" />
        <SkeletonBox height={28} />
        <SkeletonBox height={28} width="70%" />
        <SkeletonBox height={220} radius={12} />
        {[0, 1, 2, 3].map((i) => (
          <SkeletonBox key={i} height={14} />
        ))}
      </View>
    );
  }
  if (query.isError || !a) return <ErrorView error={query.error} onRetry={() => query.refetch()} />;

  const w = width - 40;
  const ratio = a.image ? aspectRatio(a.image) ?? 16 / 10 : 16 / 10;
  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <Stack.Screen
        options={{
          title: '',
          headerRight: () => (
            <View style={{ flexDirection: 'row' }}>
              <IconButton icon="text" label="Text size" onPress={() => setSizeSheet(true)} />
              <SaveButton article={a} color={p.text} />
              <IconButton icon="share-social-outline" label="Share" onPress={() => shareArticle(a)} />
            </View>
          ),
        }}
      />
      <ScrollView
        contentContainerStyle={{ paddingBottom: 40 }}
        refreshControl={<RefreshControl refreshing={query.isRefetching} onRefresh={() => refreshAll(query.refetch)} tintColor={p.accentText} colors={[p.accent]} />}
      >
        <View style={{ paddingHorizontal: 20, paddingTop: 8, gap: 12 }}>
          {a.categories[0] ? (
            <Pressable onPress={() => router.push(paths.category(a.categories[0].slug) as never)} accessibilityRole="link" style={{ alignSelf: 'flex-start' }}>
              <AppText variant="overline" color="accent">
                {a.categories[0].name}
              </AppText>
            </Pressable>
          ) : null}
          <AppText variant="display" accessibilityRole="header" selectable style={{ fontSize: 28 * scale, lineHeight: 35 * scale }}>
            {a.title}
          </AppText>
          <View style={styles.byline}>
            {a.author ? (
              <Pressable
                onPress={() => router.push(paths.author(a.author!.id) as never)}
                accessibilityRole="link"
                accessibilityLabel={`By ${a.author.name}`}
                style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}
              >
                {a.author.avatarUrl ? (
                  <AppImage image={{ variants: [{ url: a.author.avatarUrl, w: 96, h: 96 }], alt: '', caption: '' }} width={28} style={styles.avatar} rounded={14} />
                ) : (
                  <Ionicons name="person-circle-outline" size={28} color={p.subtle} />
                )}
                <AppText variant="label">{a.author.name}</AppText>
              </Pressable>
            ) : null}
            <AppText variant="caption" color="subtle">
              {[fullDate(a.publishedAt), a.readingMinutes ? `${a.readingMinutes} min read` : undefined].filter(Boolean).join(' · ')}
            </AppText>
          </View>
          {a.image ? (
            <View style={{ gap: 6 }}>
              <AppImage image={a.image} width={w} style={{ width: w, height: w / ratio }} rounded={12} />
              {a.image.caption ? (
                <AppText variant="caption" color="muted">
                  {a.image.caption}
                </AppText>
              ) : null}
            </View>
          ) : null}
        </View>
        <View style={{ paddingHorizontal: 20, paddingTop: 20 }}>
          {a.contentHtml ? <ArticleBody html={a.contentHtml} scale={scale} /> : <AppText color="muted">{a.excerpt}</AppText>}
        </View>
        {a.tags.length ? (
          <View style={styles.tags}>
            {a.tags.map((t) => (
              <Chip key={t.id} label={`#${t.name}`} onPress={() => router.push(paths.tag(t.slug) as never)} />
            ))}
          </View>
        ) : null}
        <View style={{ paddingHorizontal: 20, paddingTop: 24 }}>
          <Button kind="outlined" icon="share-social-outline" label="Share this story" onPress={() => shareArticle(a)} />
        </View>
        {a.contentHtml ? <ArticleCommunitySection article={a} /> : null}
        <Related article={a} />
      </ScrollView>
      <TextSizeSheet visible={sizeSheet} onClose={() => setSizeSheet(false)} />
    </View>
  );
}

const styles = StyleSheet.create({
  byline: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: 12 },
  avatar: { width: 28, height: 28 },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingHorizontal: 20, paddingTop: 24 },
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: { padding: 20, gap: 16, borderTopLeftRadius: 20, borderTopRightRadius: 20 },
});
