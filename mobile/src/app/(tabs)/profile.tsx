import { Ionicons } from '@expo/vector-icons';
import { useQueryClient } from '@tanstack/react-query';
import { router } from 'expo-router';
import { useState } from 'react';
import { Linking, ScrollView, View } from 'react-native';
import { clearCache } from '@/api/cache';
import { Row, TabHeader } from '@/components/Screen';
import { AppText, Chip, Divider } from '@/components/ui';
import { env, sitePage } from '@/config/env';
import { openLink } from '@/lib/links';
import { useBookmarks } from '@/stores/bookmarks';
import { TEXT_SIZES, type ThemeMode, usePreferences } from '@/stores/preferences';
import { usePalette } from '@/theme';

type Icon = keyof typeof Ionicons.glyphMap;

function Item({ icon, title, subtitle, onPress, external, trailing }: { icon: Icon; title: string; subtitle?: string; onPress?: () => void; external?: boolean; trailing?: string }) {
  const p = usePalette();
  return (
    <Row onPress={onPress} label={title}>
      <Ionicons name={icon} size={22} color={p.accentText} />
      <View style={{ flex: 1 }}>
        <AppText variant="label">{title}</AppText>
        {subtitle ? (
          <AppText variant="caption" color="muted">
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {trailing ? (
        <AppText variant="caption" color="subtle">
          {trailing}
        </AppText>
      ) : null}
      {external ? <Ionicons name="open-outline" size={16} color={p.subtle} /> : onPress ? <Ionicons name="chevron-forward" size={18} color={p.subtle} /> : null}
    </Row>
  );
}

const THEMES: [ThemeMode, string][] = [
  ['light', 'Light'],
  ['dark', 'Dark'],
  ['system', 'System'],
];

export default function ProfileScreen() {
  const p = usePalette();
  const queryClient = useQueryClient();
  const savedCount = useBookmarks((s) => s.items.length);
  const prefs = usePreferences();
  const [cleared, setCleared] = useState(false);
  const textLabel = TEXT_SIZES.find((t) => t.key === prefs.textSize)?.label;

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="Profile" />
      <ScrollView contentContainerStyle={{ paddingBottom: 40 }}>
        <Item icon="bookmark-outline" title="Saved" trailing={String(savedCount)} onPress={() => router.navigate('/saved')} />
        <Item
          icon="pricetags-outline"
          title="Your topics"
          subtitle={prefs.interestSlugs.length ? `${prefs.interestSlugs.length} chosen, shown first on Home` : 'Choose what comes first on Home'}
          onPress={() => router.push('/topics')}
        />
        <Item icon="notifications-outline" title="Notification preferences" subtitle={`${prefs.notificationTopics.length} topics`} onPress={() => router.push('/notifications')} />
        <Divider />
        <View style={{ padding: 16, gap: 10 }}>
          <AppText variant="label">Theme</AppText>
          <View style={{ flexDirection: 'row', gap: 8 }}>
            {THEMES.map(([mode, label]) => (
              <Chip key={mode} label={label} selected={prefs.themeMode === mode} onPress={() => prefs.setThemeMode(mode)} />
            ))}
          </View>
          <AppText variant="label" style={{ marginTop: 8 }}>
            Text size {textLabel ? `· ${textLabel}` : ''}
          </AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
            {TEXT_SIZES.map((t) => (
              <Chip key={t.key} label={t.label} selected={prefs.textSize === t.key} onPress={() => prefs.setTextSize(t.key)} />
            ))}
          </View>
        </View>
        <Divider />
        <Item icon="information-circle-outline" title="About AllBioHub" onPress={() => router.push('/about')} />
        <Item icon="create-outline" title="Submit a story" external onPress={() => openLink(sitePage('submit-a-story/'))} />
        <Item icon="rocket-outline" title="Submit a startup" external onPress={() => openLink(sitePage('list-your-startup/'))} />
        {env.contactEmail ? <Item icon="mail-outline" title="Contact" subtitle={env.contactEmail} onPress={() => Linking.openURL(`mailto:${env.contactEmail}`)} /> : null}
        <Item icon="shield-checkmark-outline" title="Privacy" onPress={() => router.push('/privacy')} />
        {env.termsUrl ? <Item icon="document-text-outline" title="Terms and conditions" external onPress={() => openLink(env.termsUrl)} /> : null}
        <Item
          icon="trash-bin-outline"
          title={cleared ? 'Cache cleared' : 'Clear cached content'}
          subtitle="Saved stories are kept"
          onPress={async () => {
            await clearCache();
            queryClient.clear();
            setCleared(true);
          }}
        />
        <AppText variant="caption" color="subtle" style={{ textAlign: 'center', marginTop: 24 }}>
          AllBioHub {env.version}
        </AppText>
      </ScrollView>
    </View>
  );
}
