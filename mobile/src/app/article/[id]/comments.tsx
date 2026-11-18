import { Ionicons } from '@expo/vector-icons';
import { Stack, router, useLocalSearchParams } from 'expo-router';
import { type ComponentRef, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  RefreshControl,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { pickOption } from '@/components/OptionSheet';
import { AppText, Button, Divider, ErrorView, IconButton, MAX_FONT_SCALE, StateView } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate, reportContent, UserAvatar } from '@/features/community/components';
import { requireAccount, showCommunityError } from '@/features/community/gate';
import { type CommentThread, useComments } from '@/features/community/hooks';
import type { Comment } from '@/features/community/models';
import { useSession } from '@/features/community/store';
import { relativeDate } from '@/lib/text';
import { showMessage } from '@/lib/toast';
import { fonts, radius, usePalette } from '@/theme';

/** One comment: picture, name, @username, time, text, likes and Reply. */
function CommentTile({
  comment,
  liked,
  onReply,
  onLike,
  onMore,
}: {
  comment: Comment;
  liked: boolean;
  onReply: (c: Comment) => void;
  onLike: (c: Comment) => void;
  onMore: (c: Comment) => void;
}) {
  const p = usePalette();
  const indent = 16 + comment.depth * 32;
  if (comment.deleted) {
    return (
      <AppText color="muted" style={{ paddingLeft: indent, paddingRight: 16, paddingVertical: 14, fontStyle: 'italic' }}>
        This comment was deleted.
      </AppText>
    );
  }
  const a = comment.author;
  return (
    <View style={{ flexDirection: 'row', gap: 12, paddingLeft: indent, paddingRight: 8, paddingTop: 14 }}>
      <Pressable onPress={a.uid ? () => router.push(`/u/${encodeURIComponent(a.uid)}` as never) : undefined} accessibilityLabel={`${a.displayName}'s profile`}>
        <UserAvatar name={a.displayName} photoUrl={a.photoUrl} size={comment.depth === 0 ? 36 : 28} />
      </Pressable>
      <View style={{ flex: 1, gap: 4 }}>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', columnGap: 6 }}>
          <AppText variant="label">{a.displayName}</AppText>
          {a.username ? (
            <AppText variant="caption" color="subtle">
              @{a.username}
            </AppText>
          ) : null}
          <AppText variant="caption" color="subtle">
            {`· ${relativeDate(comment.createdAt.toISOString())}${comment.editedAt ? ' · edited' : ''}`}
          </AppText>
          {comment.pinned ? <Ionicons name="pin" size={14} color={p.accentText} accessibilityLabel="Pinned" /> : null}
        </View>
        {comment.status === 'pending' ? (
          <AppText variant="caption" color="accent">
            Awaiting review · only you can see this
          </AppText>
        ) : null}
        <AppText>
          {comment.replyToUsername && comment.depth >= 2 ? (
            <AppText color="accent" style={{ fontFamily: fonts.semibold }}>{`@${comment.replyToUsername} `}</AppText>
          ) : null}
          {comment.body}
        </AppText>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <Pressable
            onPress={() => onLike(comment)}
            accessibilityRole="button"
            accessibilityLabel={`${liked ? 'Unlike' : 'Like'}, ${comment.likeCount} likes`}
            style={styles.action}
          >
            <Ionicons name={liked ? 'heart' : 'heart-outline'} size={18} color={liked ? p.accentText : p.muted} />
            <AppText variant="label" color={liked ? 'accent' : 'muted'}>
              {comment.likeCount > 0 ? String(comment.likeCount) : 'Like'}
            </AppText>
          </Pressable>
          <Pressable onPress={() => onReply(comment)} accessibilityRole="button" style={styles.action}>
            <AppText variant="label" color="muted">
              Reply
            </AppText>
          </Pressable>
          <View style={{ flex: 1 }} />
          <IconButton icon="ellipsis-horizontal" label="More" size={18} color={p.muted} onPress={() => onMore(comment)} />
        </View>
      </View>
    </View>
  );
}

function Comments() {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const { id } = useLocalSearchParams<{ id: string }>();
  const articleId = Number(id);
  const c = useComments(articleId);
  const blocked = useSession((s) => s.blocked);
  const me = useSession((s) => s.user?.uid);
  const [text, setText] = useState('');
  const [replyTo, setReplyTo] = useState<Comment | null>(null);
  const [editing, setEditing] = useState<Comment | null>(null);
  const [sending, setSending] = useState(false);
  const input = useRef<ComponentRef<typeof TextInput>>(null);

  const threads = c.items.filter((t) => !blocked.includes(t.root.author.uid) || t.root.deleted);

  async function send() {
    const body = text.trim();
    if (!body || sending) return;
    if (!(await requireAccount({ verified: true, reason: 'Sign in to join the conversation.' }))) return;
    setSending(true);
    try {
      const result = editing ? await c.edit(editing, body) : await c.add(body, replyTo ?? undefined);
      setText('');
      setReplyTo(null);
      setEditing(null);
      input.current?.blur();
      if (result.status === 'pending') showMessage('Thanks. Your comment will appear after review.');
    } catch (e) {
      // The text stays in the box so nothing is lost.
      showCommunityError(e);
    } finally {
      setSending(false);
    }
  }

  async function like(comment: Comment) {
    if (!(await requireAccount({ profile: false }))) return;
    c.toggleLike(comment).catch(showCommunityError);
  }

  async function more(comment: Comment) {
    const mine = comment.author.uid === me;
    const choice = await pickOption(
      mine
        ? [
            { value: 'edit', label: 'Edit', icon: 'create-outline' },
            { value: 'delete', label: 'Delete', icon: 'trash-outline', danger: true },
          ]
        : [
            { value: 'report', label: 'Report comment', icon: 'flag-outline' },
            { value: 'block', label: `Block @${comment.author.username}`, icon: 'ban-outline' },
          ],
    );
    if (choice === 'edit') {
      setEditing(comment);
      setReplyTo(null);
      setText(comment.body);
      input.current?.focus();
    } else if (choice === 'delete') {
      Alert.alert('Delete comment?', 'This can’t be undone.', [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Delete', style: 'destructive', onPress: () => c.remove(comment).catch(showCommunityError) },
      ]);
    } else if (choice === 'report') {
      if (await requireAccount({ profile: false })) await reportContent('comment', comment.id);
    } else if (choice === 'block') {
      if (!(await requireAccount({ profile: false }))) return;
      try {
        await community().api.setBlocked(comment.author.uid, true);
        showMessage(`You won’t see @${comment.author.username}’s comments.`);
      } catch (e) {
        showCommunityError(e);
      }
    }
  }

  const renderThread = ({ item: t }: { item: CommentThread }) => {
    const replies = t.replies.filter((r) => !blocked.includes(r.author.uid));
    const unseen = t.root.replyCount > 0 && !t.repliesLoaded;
    const tile = (x: Comment) => (
      <CommentTile
        key={x.id}
        comment={x}
        liked={c.liked.has(x.id)}
        onReply={(target) => {
          setReplyTo(target);
          setEditing(null);
          input.current?.focus();
        }}
        onLike={like}
        onMore={more}
      />
    );
    return (
      <View>
        {tile(t.root)}
        {replies.map(tile)}
        {unseen || t.hasMoreReplies ? (
          <Button
            kind="text"
            style={{ alignSelf: 'flex-start', marginLeft: 56 }}
            disabled={t.loadingReplies}
            label={
              t.loadingReplies
                ? 'Loading replies…'
                : unseen
                  ? `View ${t.root.replyCount} ${t.root.replyCount === 1 ? 'reply' : 'replies'}`
                  : 'More replies'
            }
            onPress={() => c.loadReplies(t.root.id).catch(showCommunityError)}
          />
        ) : null}
        <Divider />
      </View>
    );
  };

  const label = editing ? 'Editing your comment' : replyTo ? `Replying to @${replyTo.author.username}` : null;

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: p.background }} behavior={Platform.OS === 'ios' ? 'padding' : undefined} keyboardVerticalOffset={90}>
      {c.loading && !c.items.length ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />
      ) : c.error ? (
        <ErrorView error={c.error} onRetry={c.retry} />
      ) : (
        <FlatList
          style={{ flex: 1 }}
          data={threads}
          keyExtractor={(t) => t.root.id}
          renderItem={renderThread}
          onEndReached={c.loadMore}
          onEndReachedThreshold={0.5}
          refreshControl={<RefreshControl refreshing={false} onRefresh={c.refresh} />}
          ListEmptyComponent={<StateView icon="chatbubbles-outline" title="No comments yet" body="Start the conversation about this story." />}
          ListFooterComponent={
            c.loadMoreError ? (
              <Button kind="text" label="Couldn’t load more. Try again" onPress={c.retry} />
            ) : c.hasMore && threads.length ? (
              <ActivityIndicator style={{ margin: 16 }} color={p.accentText} />
            ) : undefined
          }
          contentContainerStyle={{ paddingBottom: 16, flexGrow: 1 }}
        />
      )}
      <View style={[styles.composer, { backgroundColor: p.surface, borderTopColor: p.border, paddingBottom: 8 + insets.bottom }]}>
        {label ? (
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <AppText variant="caption" color="muted" style={{ flex: 1 }}>
              {label}
            </AppText>
            <IconButton
              icon="close"
              label="Cancel"
              size={18}
              onPress={() => {
                if (editing) setText('');
                setEditing(null);
                setReplyTo(null);
              }}
            />
          </View>
        ) : null}
        <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 8 }}>
          <TextInput
            ref={input}
            value={text}
            onChangeText={setText}
            placeholder="Add a comment…"
            placeholderTextColor={p.subtle}
            multiline
            maxLength={2000}
            autoCapitalize="sentences"
            accessibilityLabel="Comment"
            maxFontSizeMultiplier={MAX_FONT_SCALE}
            style={[styles.input, { color: p.text, borderColor: p.border, backgroundColor: p.card, fontFamily: fonts.body }]}
          />
          <Pressable
            onPress={send}
            disabled={sending || !text.trim()}
            accessibilityRole="button"
            accessibilityLabel={editing ? 'Save' : 'Post'}
            style={[styles.send, { backgroundColor: p.accent, opacity: sending || !text.trim() ? 0.5 : 1 }]}
          >
            {sending ? <ActivityIndicator color={p.onAccent} /> : <Ionicons name={editing ? 'checkmark' : 'send'} size={18} color={p.onAccent} />}
          </Pressable>
        </View>
      </View>
    </KeyboardAvoidingView>
  );
}

export default function CommentsScreen() {
  return (
    <FeatureGate feature="comments">
      <Stack.Screen options={{ title: 'Comments' }} />
      <Comments />
    </FeatureGate>
  );
}

const styles = StyleSheet.create({
  action: { flexDirection: 'row', alignItems: 'center', gap: 4, minHeight: 36, paddingRight: 14 },
  composer: { borderTopWidth: StyleSheet.hairlineWidth, paddingHorizontal: 12, paddingTop: 8 },
  input: { flex: 1, maxHeight: 120, minHeight: 44, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: 12, paddingVertical: 10, fontSize: 15 },
  send: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
});
