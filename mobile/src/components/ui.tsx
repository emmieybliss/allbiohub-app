import { Ionicons } from '@expo/vector-icons';
import { type ReactNode, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Animated,
  Pressable,
  type PressableProps,
  type StyleProp,
  StyleSheet,
  Text,
  type TextProps,
  type TextStyle,
  View,
  type ViewStyle,
} from 'react-native';
import { errorMessage } from '@/api/errors';
import { fonts, radius, usePalette } from '@/theme';

/** System text size is respected, up to 1.6x, as in the Flutter app. */
export const MAX_FONT_SCALE = 1.6;

type Variant = 'display' | 'headline' | 'title' | 'subtitle' | 'body' | 'bodySmall' | 'label' | 'caption' | 'overline';

const variants: Record<Variant, TextStyle> = {
  display: { fontFamily: fonts.displayHeavy, fontSize: 30, lineHeight: 36 },
  headline: { fontFamily: fonts.display, fontSize: 24, lineHeight: 30 },
  title: { fontFamily: fonts.display, fontSize: 19, lineHeight: 25 },
  subtitle: { fontFamily: fonts.semibold, fontSize: 16, lineHeight: 22 },
  body: { fontFamily: fonts.body, fontSize: 15, lineHeight: 22 },
  bodySmall: { fontFamily: fonts.body, fontSize: 13, lineHeight: 18 },
  label: { fontFamily: fonts.semibold, fontSize: 14, lineHeight: 18 },
  caption: { fontFamily: fonts.medium, fontSize: 12, lineHeight: 16 },
  overline: { fontFamily: fonts.bold, fontSize: 11, lineHeight: 14, letterSpacing: 0.8, textTransform: 'uppercase' },
};

export function AppText({
  variant = 'body',
  color,
  style,
  ...props
}: TextProps & { variant?: Variant; color?: 'text' | 'muted' | 'subtle' | 'accent' | 'highlight' | 'onAccent' | string }) {
  const p = usePalette();
  const resolved =
    color === undefined || color === 'text'
      ? p.text
      : color === 'muted'
        ? p.muted
        : color === 'subtle'
          ? p.subtle
          : color === 'accent'
            ? p.accentText
            : color === 'highlight'
              ? p.highlight
              : color === 'onAccent'
                ? p.onAccent
                : color;
  return <Text maxFontSizeMultiplier={MAX_FONT_SCALE} {...props} style={[variants[variant], { color: resolved }, style]} />;
}

export function SectionHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: { label: string; onPress: () => void } }) {
  return (
    <View style={styles.sectionHeader}>
      <View style={{ flex: 1 }}>
        <AppText variant="title" accessibilityRole="header">
          {title}
        </AppText>
        {subtitle ? (
          <AppText variant="bodySmall" color="muted" style={{ marginTop: 2 }}>
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {action ? (
        <Pressable onPress={action.onPress} hitSlop={10} accessibilityRole="button">
          <AppText variant="label" color="accent">
            {action.label}
          </AppText>
        </Pressable>
      ) : null}
    </View>
  );
}

export function Button({
  label,
  onPress,
  kind = 'filled',
  icon,
  disabled,
  loading,
  style,
}: {
  label: string;
  onPress?: () => void;
  kind?: 'filled' | 'outlined' | 'text' | 'onDark' | 'onDarkOutlined';
  icon?: keyof typeof Ionicons.glyphMap;
  disabled?: boolean;
  loading?: boolean;
  style?: StyleProp<ViewStyle>;
}) {
  const p = usePalette();
  const bg =
    kind === 'filled' ? p.accent : kind === 'onDark' ? '#FFFFFF' : 'transparent';
  const fg =
    kind === 'filled' ? p.onAccent : kind === 'onDark' ? '#2B2066' : kind === 'onDarkOutlined' ? '#FFFFFF' : p.accentText;
  const border = kind === 'outlined' ? p.border : kind === 'onDarkOutlined' ? 'rgba(255,255,255,0.6)' : 'transparent';
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      accessibilityRole="button"
      accessibilityState={{ disabled: disabled || loading }}
      style={({ pressed }) => [
        styles.button,
        { backgroundColor: bg, borderColor: border, opacity: disabled ? 0.5 : pressed ? 0.8 : 1 },
        kind === 'text' && { paddingHorizontal: 8 },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <>
          {icon ? <Ionicons name={icon} size={18} color={fg} /> : null}
          <AppText variant="label" color={fg}>
            {label}
          </AppText>
        </>
      )}
    </Pressable>
  );
}

export function Chip({
  label,
  selected,
  onPress,
  style,
}: {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  style?: StyleProp<ViewStyle>;
}) {
  const p = usePalette();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityState={{ selected }}
      style={({ pressed }) => [
        styles.chip,
        { backgroundColor: selected ? p.accent : p.card, borderColor: selected ? p.accent : p.border, opacity: pressed ? 0.8 : 1 },
        style,
      ]}
    >
      <AppText variant="label" color={selected ? p.onAccent : p.text} numberOfLines={1}>
        {label}
      </AppText>
    </Pressable>
  );
}

export function IconButton({
  icon,
  onPress,
  label,
  color,
  size = 22,
  ...rest
}: { icon: keyof typeof Ionicons.glyphMap; onPress?: () => void; label: string; color?: string; size?: number } & Omit<
  PressableProps,
  'children'
>) {
  const p = usePalette();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label} hitSlop={8} style={styles.iconButton} {...rest}>
      <Ionicons name={icon} size={size} color={color ?? p.text} />
    </Pressable>
  );
}

export function Card({ children, style, onPress, label }: { children: ReactNode; style?: StyleProp<ViewStyle>; onPress?: () => void; label?: string }) {
  const p = usePalette();
  const base = [styles.card, { backgroundColor: p.card, borderColor: p.border }, style];
  if (!onPress) return <View style={base}>{children}</View>;
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label} style={({ pressed }) => [base, { opacity: pressed ? 0.85 : 1 }]}>
      {children}
    </Pressable>
  );
}

/** Pulsing placeholder while content loads. */
export function SkeletonBox({ height, width, radius: r = 8, style }: { height: number; width?: number | `${number}%`; radius?: number; style?: StyleProp<ViewStyle> }) {
  const p = usePalette();
  const [opacity] = useState(() => new Animated.Value(1));
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, { toValue: 0.5, duration: 700, useNativeDriver: true }),
        Animated.timing(opacity, { toValue: 1, duration: 700, useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [opacity]);
  return <Animated.View style={[{ height, width: width ?? '100%', borderRadius: r, backgroundColor: p.skeleton, opacity }, style]} />;
}

export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <View style={{ padding: 16, gap: 16 }} accessibilityLabel="Loading">
      {Array.from({ length: rows }, (_, i) => (
        <View key={i} style={{ flexDirection: 'row', gap: 12 }}>
          <SkeletonBox height={84} width={112} radius={12} />
          <View style={{ flex: 1, gap: 8 }}>
            <SkeletonBox height={12} width="40%" />
            <SkeletonBox height={16} />
            <SkeletonBox height={16} width="80%" />
          </View>
        </View>
      ))}
    </View>
  );
}

export function StateView({
  icon = 'newspaper-outline',
  title,
  body,
  action,
  secondary,
}: {
  icon?: keyof typeof Ionicons.glyphMap;
  title: string;
  body?: string;
  action?: { label: string; onPress: () => void; icon?: keyof typeof Ionicons.glyphMap };
  secondary?: { label: string; onPress: () => void };
}) {
  const p = usePalette();
  return (
    <View style={styles.state}>
      <View style={[styles.stateIcon, { backgroundColor: p.accentSoft }]}>
        <Ionicons name={icon} size={28} color={p.accentText} />
      </View>
      <AppText variant="title" style={{ textAlign: 'center' }}>
        {title}
      </AppText>
      {body ? (
        <AppText color="muted" style={{ textAlign: 'center' }}>
          {body}
        </AppText>
      ) : null}
      {action ? <Button label={action.label} icon={action.icon} onPress={action.onPress} style={{ marginTop: 8 }} /> : null}
      {secondary ? <Button kind="text" label={secondary.label} onPress={secondary.onPress} /> : null}
    </View>
  );
}

export function ErrorView({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const { title, body } = errorMessage(error);
  return <StateView icon="cloud-offline-outline" title={title} body={body} action={onRetry ? { label: 'Try again', onPress: onRetry, icon: 'refresh' } : undefined} />;
}

/** Shown above content that came from the offline cache. */
export function OfflineBanner() {
  const p = usePalette();
  return (
    <View style={[styles.banner, { backgroundColor: p.accentSoft }]} accessibilityRole="alert">
      <Ionicons name="cloud-offline-outline" size={16} color={p.accentText} />
      <AppText variant="bodySmall" color="accent" style={{ flex: 1 }}>
        You’re offline. Showing stories saved on this phone.
      </AppText>
    </View>
  );
}

export function Badge({ label, icon, color }: { label: string; icon?: keyof typeof Ionicons.glyphMap; color: string }) {
  return (
    <View style={[styles.badge, { borderColor: color }]}>
      {icon ? <Ionicons name={icon} size={12} color={color} /> : null}
      <AppText variant="caption" color={color}>
        {label}
      </AppText>
    </View>
  );
}

export function Divider() {
  const p = usePalette();
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: p.border }} />;
}

const styles = StyleSheet.create({
  sectionHeader: { flexDirection: 'row', alignItems: 'flex-end', paddingHorizontal: 16, paddingTop: 24, paddingBottom: 12, gap: 12 },
  button: {
    minHeight: 48,
    paddingHorizontal: 20,
    borderRadius: radius.pill,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  chip: { minHeight: 36, paddingHorizontal: 14, borderRadius: radius.pill, borderWidth: 1, justifyContent: 'center' },
  iconButton: { minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  card: { borderRadius: radius.lg, borderWidth: StyleSheet.hairlineWidth, overflow: 'hidden' },
  state: { alignItems: 'center', justifyContent: 'center', padding: 32, gap: 10, flexGrow: 1 },
  stateIcon: { width: 64, height: 64, borderRadius: 32, alignItems: 'center', justifyContent: 'center', marginBottom: 6 },
  banner: { flexDirection: 'row', alignItems: 'center', gap: 8, marginHorizontal: 16, marginTop: 8, padding: 10, borderRadius: radius.md },
  badge: { flexDirection: 'row', alignItems: 'center', gap: 4, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2 },
});
