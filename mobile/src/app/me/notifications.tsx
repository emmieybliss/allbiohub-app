import { Ionicons } from '@expo/vector-icons';
import { Stack, router } from 'expo-router';
import { ActivityIndicator, FlatList, RefreshControl, View } from 'react-native';
import { Row } from '@/components/Screen';
import { AppText, Button, Divider, ErrorView, IconButton, StateView } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate, JoinPrompt } from '@/features/community/components';
import { showCommunityError } from '@/features/community/gate';
import { useCursorList } from '@/features/community/hooks';
import type { AppNotification, NotificationKind } from '@/features/community/models';
import { openNotificationUrl } from '@/features/community/openUrl';
import { useUser } from '@/features/community/store';
import { relativeDate } from '@/lib/text';
import { usePalette } from '@/theme';

const ICONS: Record<NotificationKind, keyof typeof Ionicons.glyphMap> = {
  comment_reply: 'return-down-forward-outline',
  comment_like: 'heart-outline',
  startup_story: 'rocket-outline',
  founder_story: 'person-outline',
  topic_story: 'newspaper-outline',
  submission_update: 'create-outline',
  claim_update: 'shield-checkmark-outline',
  other: 'notifications-outline',
};

/** Replies, likes, followed startups and topics, and submission updates, newest first. */
function NotificationCenter() {
  const p = usePalette();
  const user = useUser();
  const { api } = community();
  const list = useCursorList<AppNotification>(user?.uid ?? '', (cursor) =>
    user ? api.notifications(user.uid, cursor) : Promise.resolve({ items: [], hasMore: false }),
  );

  const open = (n: AppNotification) => {
    if (!n.read && user) {
      api.markRead(user.uid, n.id).catch(() => {});
      list.update((items) => items.map((i) => (i.id === n.id ? { ...i, read: true } : i)));
    }
    openNotificationUrl(n.url);
  };

  const header = (
    <Stack.Screen
      options={{
        title: 'Notifications',
        headerRight: () => (
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            {user && list.items.some((n) => !n.read) ? (
              <Button
                kind="text"
                label="Mark all read"
                onPress={async () => {
                  try {
                    await api.markAllRead();
                    await list.refresh();
                  } catch (e) {
                    showCommunityError(e);
                  }
                }}
              />
            ) : null}
            <IconButton icon="options-outline" label="Notification preferences" onPress={() => router.push('/notifications')} />
          </View>
        ),
      }}
    />
  );

  if (!user) {
    return (
      <View style={{ padding: 20, backgroundColor: p.background, flex: 1 }}>
        {header}
        <JoinPrompt
          title="Your notifications"
          message="Sign in to hear about replies to your comments and new stories about startups and topics you follow."
        />
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      {header}
      {list.loading && !list.items.length ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />
      ) : list.error ? (
        <ErrorView error={list.error} onRetry={list.retry} />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(n) => n.id}
          onEndReached={list.loadMore}
          refreshControl={<RefreshControl refreshing={false} onRefresh={list.refresh} />}
          contentContainerStyle={{ flexGrow: 1 }}
          ListEmptyComponent={
            <StateView
              icon="notifications-outline"
              title="Nothing new"
              body="Follow startups and topics to hear about new stories. Replies to your comments show here too."
            />
          }
          ListFooterComponent={list.loadMoreError ? <Button kind="text" label="Couldn’t load more. Try again" onPress={list.retry} /> : undefined}
          renderItem={({ item: n }) => (
            <View>
              <Row onPress={() => open(n)} label={n.title}>
                <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
                  <Ionicons name={ICONS[n.kind]} size={20} color={p.accentText} />
                </View>
                <View style={{ flex: 1, gap: 2 }}>
                  <AppText variant={n.read ? 'body' : 'label'}>{n.title}</AppText>
                  {n.body ? (
                    <AppText variant="bodySmall" color="muted" numberOfLines={3}>
                      {n.body}
                    </AppText>
                  ) : null}
                  <AppText variant="caption" color="subtle">
                    {relativeDate(n.createdAt.toISOString())}
                  </AppText>
                </View>
                {!n.read ? <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: p.accent }} accessibilityLabel="Unread" /> : null}
              </Row>
              <Divider />
            </View>
          )}
        />
      )}
    </View>
  );
}

export default function NotificationCenterScreen() {
  return (
    <FeatureGate feature="notificationCenter">
      <NotificationCenter />
    </FeatureGate>
  );
}
