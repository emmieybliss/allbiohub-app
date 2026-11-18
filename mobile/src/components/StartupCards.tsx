import { router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { startupLocation } from '@/api/startups';
import { paths } from '@/lib/deepLinks';
import type { Startup } from '@/models/types';
import { radius, usePalette } from '@/theme';
import { AppImage } from './AppImage';
import { AppText, Badge } from './ui';

export function StartupLogo({ startup, size = 52 }: { startup: Startup; size?: number }) {
  const p = usePalette();
  if (startup.logo) {
    return (
      <AppImage
        image={startup.logo}
        width={size}
        allowCropped
        rounded={radius.md}
        style={{ width: size, height: size, borderWidth: StyleSheet.hairlineWidth, borderColor: p.border, backgroundColor: '#FFFFFF' }}
      />
    );
  }
  const initials = startup.name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join('');
  return (
    <View style={{ width: size, height: size, borderRadius: radius.md, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
      <AppText variant="subtitle" color="accent">
        {initials}
      </AppText>
    </View>
  );
}

/** Badges only for what the directory marks exactly true. */
export function StartupBadges({ startup }: { startup: Startup }) {
  const p = usePalette();
  if (!startup.verified && !startup.claimed && !startup.featured) return null;
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6 }}>
      {startup.verified ? <Badge label="Verified" icon="checkmark-circle" color={p.verified} /> : null}
      {startup.claimed ? <Badge label="Claimed" icon="shield-checkmark-outline" color={p.accentText} /> : null}
      {startup.featured ? <Badge label="Featured" icon="star" color={p.highlight} /> : null}
    </View>
  );
}

function open(s: Startup) {
  router.push(paths.startup(s.slug) as never);
}

export function StartupRow({ startup }: { startup: Startup }) {
  const p = usePalette();
  const meta = [startup.industry, startupLocation(startup), startup.founded ? `Founded ${startup.founded}` : undefined].filter(Boolean).join(' · ');
  return (
    <Pressable
      onPress={() => open(startup)}
      accessibilityRole="button"
      accessibilityLabel={startup.name}
      style={({ pressed }) => [styles.row, { backgroundColor: p.card, borderColor: p.border, opacity: pressed ? 0.85 : 1 }]}
    >
      <StartupLogo startup={startup} />
      <View style={{ flex: 1, gap: 4 }}>
        <AppText variant="subtitle" numberOfLines={1}>
          {startup.name}
        </AppText>
        {startup.tagline || startup.description ? (
          <AppText variant="bodySmall" color="muted" numberOfLines={2}>
            {startup.tagline ?? startup.description}
          </AppText>
        ) : null}
        {meta ? (
          <AppText variant="caption" color="subtle" numberOfLines={1}>
            {meta}
          </AppText>
        ) : null}
        <StartupBadges startup={startup} />
      </View>
    </Pressable>
  );
}

export function StartupRailCard({ startup }: { startup: Startup }) {
  const p = usePalette();
  return (
    <Pressable
      onPress={() => open(startup)}
      accessibilityRole="button"
      accessibilityLabel={startup.name}
      style={({ pressed }) => [styles.rail, { backgroundColor: p.card, borderColor: p.border, opacity: pressed ? 0.85 : 1 }]}
    >
      <StartupLogo startup={startup} size={44} />
      <AppText variant="subtitle" numberOfLines={1}>
        {startup.name}
      </AppText>
      <AppText variant="bodySmall" color="muted" numberOfLines={2} style={{ minHeight: 36 }}>
        {startup.tagline ?? startup.description ?? ''}
      </AppText>
      <AppText variant="caption" color="subtle" numberOfLines={1}>
        {[startup.industry, startup.country].filter(Boolean).join(' · ')}
      </AppText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 12, padding: 14, marginHorizontal: 16, borderRadius: radius.lg, borderWidth: StyleSheet.hairlineWidth },
  rail: { width: 200, gap: 8, padding: 14, borderRadius: radius.lg, borderWidth: StyleSheet.hairlineWidth },
});
