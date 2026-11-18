import { Stack, router } from 'expo-router';
import { ActivityIndicator, FlatList, RefreshControl, View } from 'react-native';
import { Row } from '@/components/Screen';
import { AppText, Button, Divider, ErrorView, StateView } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate } from '@/features/community/components';
import { useCursorList } from '@/features/community/hooks';
import type { Comment } from '@/features/community/models';
import { useUser } from '@/features/community/store';
import { paths } from '@/lib/deepLinks';
import { relativeDate } from '@/lib/text';
import { usePalette } from '@/theme';

const STATUS: Record<Comment['status'], string | null> = { pending: 'Awaiting review', rejected: 'Not published', removed: 'Removed', approved: null };

/** The person's own comments, newest first, including ones awaiting review. */
function MyComments() {
  const p = usePalette();
  const uid = useUser()?.uid;
  const list = useCursorList<Comment>(uid ?? '', (cursor) =>
    uid ? community().api.commentsBy(uid, cursor) : Promise.resolve({ items: [], hasMore: false }),
  );
  if (list.loading && !list.items.length) return <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />;
  if (list.error) return <ErrorView error={list.error} onRetry={list.retry} />;
  return (
    <FlatList
      style={{ backgroundColor: p.background }}
      data={list.items}
      keyExtractor={(c) => c.id}
      onEndReached={list.loadMore}
      refreshControl={<RefreshControl refreshing={false} onRefresh={list.refresh} />}
      contentContainerStyle={{ flexGrow: 1 }}
      ListEmptyComponent={<StateView icon="chatbubbles-outline" title="No comments yet" body="Your comments on stories will show here." />}
      ListFooterComponent={list.loadMoreError ? <Button kind="text" label="Couldn’t load more. Try again" onPress={list.retry} /> : undefined}
      renderItem={({ item: c }) => (
        <View>
          <Row onPress={() => router.push(paths.comments(c.articleId) as never)}>
            <View style={{ flex: 1, gap: 4 }}>
              <AppText numberOfLines={3}>{c.deleted ? 'Deleted comment' : c.body}</AppText>
              <AppText variant="caption" color="subtle">
                {[relativeDate(c.createdAt.toISOString()), c.deleted ? 'Deleted' : STATUS[c.status], c.likeCount > 0 ? `${c.likeCount} likes` : null]
                  .filter(Boolean)
                  .join(' · ')}
              </AppText>
            </View>
          </Row>
          <Divider />
        </View>
      )}
    />
  );
}

export default function MyCommentsScreen() {
  return (
    <FeatureGate feature="comments">
      <Stack.Screen options={{ title: 'My comments' }} />
      <MyComments />
    </FeatureGate>
  );
}
