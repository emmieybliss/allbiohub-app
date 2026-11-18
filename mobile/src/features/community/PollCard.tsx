import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Pressable, Share, StyleSheet, View } from 'react-native';
import { AppText, IconButton } from '@/components/ui';
import { env } from '@/config/env';
import { radius, usePalette } from '@/theme';
import { requireAccount, showCommunityError } from './gate';
import { usePoll } from './hooks';
import { type Poll, pollIsOpen, pollPercentages } from './models';

const dateFormat = new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short', year: 'numeric' });

/** A poll or Question of the Day. Vote once (or change it when allowed); results show after voting or when it closes. */
export function PollCard({ poll }: { poll: Poll }) {
  const p = usePalette();
  const state = usePoll(poll);
  const current = state.poll;
  const percentages = pollPercentages(current);
  const open = pollIsOpen(current);

  const vote = async (optionId: string) => {
    Haptics.selectionAsync().catch(() => {});
    if (!(await requireAccount({ profile: false, reason: 'Sign in to vote. Your vote is never shown to anyone.' }))) return;
    try {
      await state.vote(optionId);
    } catch (e) {
      showCommunityError(e);
    }
  };

  const footer = [
    state.showResults || current.totalVotes > 0 ? `${current.totalVotes} ${current.totalVotes === 1 ? 'vote' : 'votes'}` : null,
    !open ? 'Closed' : null,
    open && state.hasVoted && current.allowChange ? 'You can change your vote' : null,
    open && current.expiresAt ? `Closes ${dateFormat.format(current.expiresAt)}` : null,
  ].filter(Boolean);

  return (
    <View style={[styles.card, { backgroundColor: p.card, borderColor: p.border }]}>
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <AppText variant="overline" color="accent" style={{ flex: 1 }}>
          {current.kind === 'qotd' ? 'Question of the Day' : 'Poll'}
        </AppText>
        <IconButton
          icon="share-outline"
          label="Share poll"
          size={18}
          onPress={() => Share.share({ message: `${current.question}\n\nVote in the AllBioHub app:\n${env.siteUrl}` }).catch(() => {})}
        />
      </View>
      <AppText variant="title">{current.question}</AppText>
      <View style={{ gap: 8, marginTop: 6 }}>
        {current.options.map((o) => {
          const selected = state.myVote === o.id;
          const percent = percentages[o.id] ?? 0;
          const enabled = state.canVote && !state.busy;
          return (
            <Pressable
              key={o.id}
              onPress={enabled ? () => vote(o.id) : undefined}
              disabled={!enabled}
              accessibilityRole="button"
              accessibilityState={{ selected, disabled: !enabled }}
              accessibilityLabel={state.showResults ? `${o.label}, ${percent} percent` : o.label}
              style={[styles.option, { borderColor: selected ? p.accent : p.border }]}
            >
              {state.showResults ? (
                <View style={[StyleSheet.absoluteFill, { width: `${percent}%`, backgroundColor: selected ? p.accentSoft : p.skeleton }]} />
              ) : null}
              {selected ? <Ionicons name="checkmark-circle" size={18} color={p.accentText} /> : null}
              <AppText style={{ flex: 1 }}>{o.label}</AppText>
              {state.showResults ? <AppText variant="label">{`${percent}%`}</AppText> : null}
            </Pressable>
          );
        })}
      </View>
      {footer.length ? (
        <AppText variant="caption" color="subtle" style={{ marginTop: 4 }}>
          {footer.join(' · ')}
        </AppText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: { borderRadius: radius.lg, borderWidth: 1, padding: 16, gap: 6 },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    borderWidth: 1,
    borderRadius: radius.md,
    paddingHorizontal: 14,
    minHeight: 48,
    overflow: 'hidden',
  },
});
