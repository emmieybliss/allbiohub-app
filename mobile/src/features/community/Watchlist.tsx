import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, View } from 'react-native';
import { useStartup, useStartupCoverage } from '@/api/queries';
import { AppImage } from '@/components/AppImage';
import { AppText, Divider } from '@/components/ui';
import { paths } from '@/lib/deepLinks';
import { singleImage } from '@/lib/images';
import { relativeDate } from '@/lib/text';
import { radius, usePalette } from '@/theme';
import { FollowButton } from './components';
import type { FollowedItem } from './models';

/** A followed startup with its industry, country, stage and latest AllBioHub story, as far as the directory has them. */
export function WatchlistRow({ item }: { item: FollowedItem }) {
  const p = usePalette();
  const startup = useStartup(item.target.id).data;
  const latest = useStartupCoverage(item.target.label).data?.[0];
  const details = [startup?.industry, startup?.country, startup?.stage].filter(Boolean).join(' · ');
  const logo = startup?.logo ?? (item.image ? singleImage(item.image) : undefined);
  return (
    <View>
      <Pressable
        onPress={() => router.push(paths.startup(item.target.id) as never)}
        accessibilityRole="button"
        style={{ flexDirection: 'row', gap: 12, padding: 16, alignItems: 'flex-start' }}
      >
        {logo ? (
          <AppImage image={logo} width={48} allowCropped rounded={radius.sm} style={{ width: 48, height: 48 }} />
        ) : (
          <View style={{ width: 48, height: 48, borderRadius: radius.sm, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="rocket-outline" size={22} color={p.accentText} />
          </View>
        )}
        <View style={{ flex: 1, gap: 2 }}>
          <AppText variant="subtitle">{startup?.name ?? item.target.label}</AppText>
          {details ? (
            <AppText variant="bodySmall" color="muted">
              {details}
            </AppText>
          ) : null}
          {latest ? (
            <AppText
              variant="bodySmall"
              color="accent"
              numberOfLines={2}
              onPress={() => router.push(paths.article(latest.id) as never)}
              style={{ marginTop: 4 }}
            >
              {`Latest: ${latest.title} · ${relativeDate(latest.publishedAt)}`}
            </AppText>
          ) : null}
        </View>
        <FollowButton dense target={item.target} />
      </Pressable>
      <Divider />
    </View>
  );
}
