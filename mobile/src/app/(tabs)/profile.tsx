import { Ionicons } from '@expo/vector-icons';
import { useQueryClient } from '@tanstack/react-query';
import { router } from 'expo-router';
import { useState } from 'react';
import { Linking, ScrollView, View } from 'react-native';
import { clearCache } from '@/api/cache';
import { Row, TabHeader } from '@/components/Screen';
import { AppText, Button, Chip, Divider } from '@/components/ui';
import { env, sitePage } from '@/config/env';
import { CountBadge, JoinPrompt, ProfileHeader } from '@/features/community/components';
import { useFeature, useSavedEntities, useSession } from '@/features/community/store';
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

/** Account part of Profile: a join prompt for guests, otherwise the profile and the person's own lists. */
function AccountSection() {
  const accounts = useFeature('accounts');
  const center = useFeature('notificationCenter');
  const comments = useFeature('comments');
  const polls = useFeature('polls');
  const topics = useFeature('topicFollows');
  const watchlist = useFeature('startupFollows');
  const founders = useFeature('founderFollows');
  const stories = useFeature('storySubmissions');
  const startups = useFeature('startupSubmissions');
  const claims = useFeature('startupClaims');
  const following = topics || watchlist || founders;
  const submissions = stories || startups || claims;
  const ready = useSession((s) => s.ready);
  const user = useSession((s) => s.user);
  const profile = useSession((s) => s.profile);
  const unread = useSession((s) => s.unread);
  if (!accounts || !ready) return null;
  if (!user) {
    return (
      <View style={{ padding: 16 }}>
        <JoinPrompt title="Join the AllBioHub community" message="Sign in to comment, follow topics, startups and founders, vote in polls and keep your saved items on every phone." />
      </View>
    );
  }
  return (
    <>
      <View style={{ padding: 16, gap: 12 }}>
        {profile ? (
          <ProfileHeader profile={profile} isMe />
        ) : profile === null ? (
          <>
            <AppText color="muted">{user.email ? `Signed in as ${user.email}` : 'Signed in'}</AppText>
            <Button label="Choose a username" onPress={() => router.push('/account/username')} />
          </>
        ) : null}
      </View>
      {profile ? <Item icon="person-circle-outline" title="Edit profile" onPress={() => router.push('/me/edit')} /> : null}
      {center ? (
        <Row onPress={() => router.push('/me/notifications')} label="Notifications">
          <ItemIcon icon="notifications-outline" />
          <AppText variant="label" style={{ flex: 1 }}>
            Notifications
          </AppText>
          <CountBadge count={unread} />
          <ItemChevron />
        </Row>
      ) : null}
      {following ? <Item icon="heart-outline" title="Following" onPress={() => router.push('/me/following')} /> : null}
      {watchlist ? <Item icon="eye-outline" title="Startup watchlist" onPress={() => router.push('/me/watchlist')} /> : null}
      {comments ? <Item icon="chatbubbles-outline" title="My comments" onPress={() => router.push('/me/comments')} /> : null}
      {submissions ? <Item icon="document-text-outline" title="My submissions" onPress={() => router.push('/me/submissions')} /> : null}
      {polls ? <Item icon="stats-chart-outline" title="Polls" onPress={() => router.push('/polls')} /> : null}
      <Item icon="settings-outline" title="Account settings" onPress={() => router.push('/me/settings')} />
      <Divider />
    </>
  );
}

function ItemIcon({ icon }: { icon: Icon }) {
  const p = usePalette();
  return <Ionicons name={icon} size={22} color={p.accentText} />;
}

function ItemChevron() {
  const p = usePalette();
  return <Ionicons name="chevron-forward" size={18} color={p.subtle} />;
}

const THEMES: [ThemeMode, string][] = [
  ['light', 'Light'],
  ['dark', 'Dark'],
  ['system', 'System'],
];

export default function ProfileScreen() {
  const p = usePalette();
  const queryClient = useQueryClient();
  const savedCount = useBookmarks((s) => s.items.length) + useSavedEntities((s) => s.items.length);
  const storyForm = useFeature('storySubmissions');
  const startupForm = useFeature('startupSubmissions');
  const prefs = usePreferences();
  const [cleared, setCleared] = useState(false);
  const textLabel = TEXT_SIZES.find((t) => t.key === prefs.textSize)?.label;

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <TabHeader title="Profile" />
      <ScrollView contentContainerStyle={{ paddingBottom: 40 }}>
        <AccountSection />
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
        <Item
          icon="create-outline"
          title="Submit a story"
          external={!storyForm}
          onPress={() => (storyForm ? router.push('/submit/story') : openLink(sitePage('submit-a-story/')))}
        />
        <Item
          icon="rocket-outline"
          title="Submit a startup"
          external={!startupForm}
          onPress={() => (startupForm ? router.push('/submit/startup') : openLink(sitePage('list-your-startup/')))}
        />
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
