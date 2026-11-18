import { Ionicons } from '@expo/vector-icons';
import { Fragment, useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { AppImage } from '@/components/AppImage';
import { AppText, MAX_FONT_SCALE } from '@/components/ui';
import { aspectRatio } from '@/lib/images';
import { openLink } from '@/lib/links';
import { fonts, radius, usePalette, type Palette } from '@/theme';
import { type Block, type Inline, parseStoryHtml } from './htmlBlocks';

/** Native rendering of a story's HTML. [scale] is the reader's text size setting. */
export function ArticleBody({ html, scale }: { html: string; scale: number }) {
  const blocks = useMemo(() => parseStoryHtml(html), [html]);
  const p = usePalette();
  return (
    <View style={{ gap: 16 }}>
      {blocks.map((b, i) => (
        <BlockView key={i} block={b} scale={scale} p={p} />
      ))}
    </View>
  );
}

function Spans({ spans, style, p }: { spans: Inline[]; style: object; p: Palette }) {
  return (
    <Text style={style} maxFontSizeMultiplier={MAX_FONT_SCALE} selectable>
      {spans.map((s, i) => (
        <Text
          key={i}
          onPress={s.href ? () => openLink(s.href!) : undefined}
          accessibilityRole={s.href ? 'link' : undefined}
          style={[
            s.bold && { fontFamily: fonts.bold },
            s.italic && { fontStyle: 'italic' },
            s.underline && { textDecorationLine: 'underline' },
            s.strike && { textDecorationLine: 'line-through' },
            s.code && { fontFamily: 'monospace', backgroundColor: p.accentSoft },
            s.href && { color: p.accentText, textDecorationLine: 'underline' },
          ]}
        >
          {s.text}
        </Text>
      ))}
    </Text>
  );
}

const HEADING_SIZES: Record<number, number> = { 1: 26, 2: 23, 3: 20, 4: 18, 5: 16, 6: 15 };

function BlockView({ block, scale, p }: { block: Block; scale: number; p: Palette }) {
  const { width } = useWindowDimensions();
  const body = { fontFamily: fonts.body, fontSize: 17 * scale, lineHeight: 28 * scale, color: p.text };
  switch (block.type) {
    case 'paragraph':
      return <Spans spans={block.spans} style={body} p={p} />;
    case 'heading': {
      const size = HEADING_SIZES[block.level] * scale;
      return (
        <View accessibilityRole="header" style={{ marginTop: 8 }}>
          <Spans spans={block.spans} style={{ fontFamily: fonts.display, fontSize: size, lineHeight: size * 1.3, color: p.text }} p={p} />
        </View>
      );
    }
    case 'list':
      return (
        <View style={{ gap: 8 }}>
          {block.items.map((item, i) => (
            <View key={i} style={{ flexDirection: 'row', gap: 10 }}>
              <AppText style={[body, { minWidth: 18 }]} color="accent">
                {block.ordered ? `${i + 1}.` : '•'}
              </AppText>
              <View style={{ flex: 1, gap: 8 }}>
                {item.map((b, j) => (
                  <BlockView key={j} block={b} scale={scale} p={p} />
                ))}
              </View>
            </View>
          ))}
        </View>
      );
    case 'quote':
      return (
        <View style={[styles.quote, { borderLeftColor: p.highlight }]}>
          {block.blocks.map((b, i) => (
            <Fragment key={i}>
              {b.type === 'paragraph' ? (
                <Spans spans={b.spans} style={[body, { fontFamily: fonts.display, fontSize: 19 * scale, lineHeight: 29 * scale }]} p={p} />
              ) : (
                <BlockView block={b} scale={scale} p={p} />
              )}
            </Fragment>
          ))}
        </View>
      );
    case 'rule':
      return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: p.border, marginVertical: 8 }} />;
    case 'image': {
      const w = width - 40;
      const ratio = aspectRatio(block.image) ?? 16 / 10;
      const img = <AppImage image={block.image} width={w} style={{ width: w, height: w / ratio }} rounded={radius.md} />;
      return block.href ? (
        <Pressable onPress={() => openLink(block.href!)} accessibilityRole="link" accessibilityLabel={block.image.alt || 'Open link'}>
          {img}
        </Pressable>
      ) : (
        img
      );
    }
    case 'caption':
      return <Spans spans={block.spans} style={{ fontFamily: fonts.body, fontSize: 13 * scale, lineHeight: 18 * scale, color: p.muted, marginTop: -8 }} p={p} />;
    case 'embed': {
      const icon = block.kind === 'youtube' ? 'logo-youtube' : block.kind === 'video' ? 'play-circle-outline' : 'open-outline';
      return (
        <Pressable
          onPress={() => openLink(block.url)}
          accessibilityRole="link"
          style={({ pressed }) => [styles.embed, { backgroundColor: p.accentSoft, opacity: pressed ? 0.8 : 1 }]}
        >
          <Ionicons name={icon} size={26} color={block.kind === 'youtube' ? '#FF0033' : p.accentText} />
          <AppText variant="label" color="accent" style={{ flex: 1 }}>
            {block.label}
          </AppText>
          <Ionicons name="chevron-forward" size={18} color={p.accentText} />
        </Pressable>
      );
    }
    case 'table':
      return (
        <ScrollView horizontal showsHorizontalScrollIndicator>
          <View style={[styles.table, { borderColor: p.border }]}>
            {block.rows.map((row, r) => (
              <View key={r} style={{ flexDirection: 'row', backgroundColor: r === 0 ? p.accentSoft : 'transparent' }}>
                {row.map((cell, c) => (
                  <View key={c} style={[styles.cell, { borderColor: p.border }]}>
                    <Spans spans={cell} style={{ fontFamily: r === 0 ? fonts.semibold : fonts.body, fontSize: 14 * scale, color: p.text }} p={p} />
                  </View>
                ))}
              </View>
            ))}
          </View>
        </ScrollView>
      );
    case 'code':
      return (
        <ScrollView horizontal style={[styles.code, { backgroundColor: p.accentSoft }]}>
          <Text selectable style={{ fontFamily: 'monospace', fontSize: 13 * scale, color: p.text }}>
            {block.text}
          </Text>
        </ScrollView>
      );
  }
}

const styles = StyleSheet.create({
  quote: { borderLeftWidth: 3, paddingLeft: 14, gap: 10 },
  embed: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderRadius: radius.md, minHeight: 56 },
  table: { borderWidth: StyleSheet.hairlineWidth, borderRadius: radius.sm },
  cell: { width: 160, padding: 8, borderWidth: StyleSheet.hairlineWidth },
  code: { padding: 12, borderRadius: radius.sm },
});
