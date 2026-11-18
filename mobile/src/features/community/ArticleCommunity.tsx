import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/ui';
import { paths } from '@/lib/deepLinks';
import { htmlToPlainText } from '@/lib/text';
import type { Article } from '@/models/types';
import { radius, usePalette } from '@/theme';
import { FollowButton, IconRow, UserAvatar } from './components';
import { requireAccount, showCommunityError } from './gate';
import { useMentionedStartups, useReaction } from './hooks';
import { REACTIONS } from './models';
import { useFeature, useSession } from './store';

/** ❤️ Love · 🔥 Interesting · 🤯 Wow · 💡 Informative. One per person; real totals, hidden while zero. */
function ReactionBar({ reaction }: { reaction: ReturnType<typeof useReaction> }) {
  const p = usePalette();
  const react = async (key: (typeof REACTIONS)[number]['key']) => {
    Haptics.selectionAsync().catch(() => {});
    if (!(await requireAccount({ profile: false, reason: 'Sign in to react to stories.' }))) return;
    try {
      await reaction.toggle(key);
    } catch (e) {
      showCommunityError(e);
    }
  };
  return (
    <View style={{ gap: 10 }}>
      <AppText variant="subtitle">What did you think?</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {REACTIONS.map((r) => {
          const selected = reaction.mine === r.key;
          const count = reaction.engagement.reactions[r.key] ?? 0;
          return (
            <Pressable
              key={r.key}
              onPress={() => react(r.key)}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              accessibilityLabel={`${r.label}${count > 0 ? `, ${count}` : ''}${selected ? ', your reaction' : ''}`}
              style={({ pressed }) => [
                styles.reaction,
                { backgroundColor: selected ? p.accentSoft : 'transparent', borderColor: selected ? p.accent : p.border, opacity: pressed ? 0.8 : 1 },
              ]}
            >
              <AppText style={{ fontSize: 16 }}>{r.emoji}</AppText>
              <AppText variant="label" color={selected ? 'accent' : 'text'}>
                {count > 0 ? String(count) : r.label}
              </AppText>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

/** "Comments · Join the conversation": the real comment count and the way into the conversation. */
function CommentsEntry({ articleId, title, count }: { articleId: number; title: string; count: number }) {
  const p = usePalette();
  const me = useSession((s) => s.profile);
  return (
    <View style={{ gap: 12 }}>
      <View style={{ flexDirection: 'row', alignItems: 'baseline', gap: 8 }}>
        <AppText variant="title">Comments</AppText>
        {count > 0 ? (
          <AppText variant="subtitle" color="muted">
            {String(count)}
          </AppText>
        ) : null}
      </View>
      <Pressable
        onPress={() => router.push({ pathname: '/article/[id]/comments', params: { id: String(articleId), title } })}
        accessibilityRole="button"
        style={({ pressed }) => [styles.entry, { backgroundColor: p.card, borderColor: p.border, opacity: pressed ? 0.85 : 1 }]}
      >
        <UserAvatar name={me?.displayName} photoUrl={me?.photoUrl} size={32} />
        <AppText color="muted" style={{ flex: 1 }}>
          {count === 0 ? 'Join the conversation' : 'Read and join the conversation'}
        </AppText>
        <Ionicons name="chevron-forward" size={18} color={p.subtle} />
      </Pressable>
    </View>
  );
}

/**
 * Reactions, topic and startup follows, and the way into comments, under a
 * story. Each part shows only when its feature is on, so with everything off
 * the reader looks exactly as before.
 */
export function ArticleCommunitySection({ article }: { article: Article }) {
  const reactions = useFeature('reactions');
  const comments = useFeature('comments');
  const topics = useFeature('topicFollows');
  const startups = useMentionedStartups(article);
  const reaction = useReaction(article.id);
  const topic = article.categories[0];

  const parts: ReactNode[] = [];
  if (reactions) parts.push(<ReactionBar key="reactions" reaction={reaction} />);
  if (topic && topics) {
    parts.push(
      <IconRow
        key="topic"
        icon="newspaper-outline"
        title={`More on ${topic.name}`}
        subtitle="Hear when AllBioHub publishes a new story on this topic."
        trailing={<FollowButton dense target={{ kind: 'topic', id: topic.slug, label: topic.name }} />}
      />,
    );
  }
  if (startups.length) {
    parts.push(
      <View key="startups" style={{ gap: 12 }}>
        <AppText variant="subtitle">Interested in this startup?</AppText>
        {startups.map((s) => (
          <IconRow
            key={s.slug}
            icon="rocket-outline"
            title={s.name}
            subtitle={`Get alerts when AllBioHub covers ${s.name}.`}
            onPress={() => router.push(paths.startup(s.slug) as never)}
            trailing={<FollowButton dense target={{ kind: 'startup', id: s.slug, label: s.name }} />}
          />
        ))}
      </View>,
    );
  }
  if (comments) {
    parts.push(<CommentsEntry key="comments" articleId={article.id} title={htmlToPlainText(article.title)} count={reaction.engagement.commentCount} />);
  }
  if (!parts.length) return null;
  return <View style={{ paddingHorizontal: 20, paddingTop: 28, gap: 20 }}>{parts}</View>;
}

const styles = StyleSheet.create({
  reaction: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: 12, minHeight: 40 },
  entry: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, borderRadius: radius.md, borderWidth: 1 },
});
