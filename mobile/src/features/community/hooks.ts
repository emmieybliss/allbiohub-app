import { useQuery } from '@tanstack/react-query';
import { useCallback, useEffect, useRef, useState } from 'react';
import { fetchLatest } from '@/api/articles';
import { useCategories } from '@/api/queries';
import { fetchStartups } from '@/api/startups';
import { escapeRegExp } from '@/lib/text';
import type { Article, Startup } from '@/models/types';
import { usePreferences } from '@/stores/preferences';
import { community } from './api';
import {
  type ArticleEngagement,
  type Comment,
  type CursorPage,
  EMPTY_ENGAGEMENT,
  type Poll,
  pollIsOpen,
  pollWithVote,
  type ReactionType,
  withReactionChange,
} from './models';
import { useFeature, useSession, useUser } from './store';

// Reactions -----------------------------------------------------------------------

/**
 * Reaction counts for one story, live from the server, plus the person's own
 * reaction. Changing it updates the screen at once and rolls back if the
 * server refuses or the phone is offline.
 */
export function useReaction(articleId: number) {
  const uid = useUser()?.uid;
  // `mineFor` is the account `mine` belongs to, so signing out hides it without an extra render.
  const [state, setState] = useState<{ engagement: ArticleEngagement; mine: ReactionType | null; mineFor: string | null; busy: boolean }>({
    engagement: EMPTY_ENGAGEMENT,
    mine: null,
    mineFor: null,
    busy: false,
  });
  const busy = useRef(false);

  useEffect(() => {
    const { api } = community();
    const off = api.watchEngagement(articleId, (engagement) => {
      // While a change is in flight the optimistic counts stay on screen.
      if (!busy.current) setState((s) => ({ ...s, engagement }));
    });
    let alive = true;
    if (uid) {
      api.myReaction(articleId).then(
        (mine) => alive && !busy.current && setState((s) => ({ ...s, mine, mineFor: uid })),
        () => {},
      );
    }
    return () => {
      alive = false;
      off();
    };
  }, [articleId, uid]);

  const mine = uid && state.mineFor === uid ? state.mine : null;

  /** Selects [reaction], or clears it when it's already selected. Throws after rolling back. */
  const toggle = useCallback(
    async (reaction: ReactionType) => {
      if (busy.current) return;
      const before = { ...state, mine: mine };
      const next = mine === reaction ? null : reaction;
      busy.current = true;
      setState({ engagement: withReactionChange(before.engagement, mine, next), mine: next, mineFor: uid ?? null, busy: true });
      try {
        const engagement = await community().api.setReaction(articleId, next);
        setState({ engagement, mine: next, mineFor: uid ?? null, busy: false });
      } catch (e) {
        setState({ ...before, busy: false });
        throw e;
      } finally {
        busy.current = false;
      }
    },
    [articleId, state, mine, uid],
  );

  return { engagement: state.engagement, busy: state.busy, mine, toggle };
}

// Paged lists -------------------------------------------------------------------------

export type ListState<T> = {
  items: T[];
  cursor?: unknown;
  hasMore: boolean;
  loading: boolean;
  /** The first page failed (nothing to show). */
  error?: unknown;
  /** A later page failed (what's loaded stays). */
  loadMoreError?: unknown;
};

/** A list loaded a page at a time from a cursor-paginated collection. Reloads when [key] changes. */
export function useCursorList<T>(key: string, fetchPage: (cursor: unknown) => Promise<CursorPage<T>>) {
  const [state, setState] = useState<ListState<T>>({ items: [], hasMore: true, loading: true });
  const generation = useRef(0);
  const stateRef = useRef(state);
  stateRef.current = state;
  const fetchRef = useRef(fetchPage);
  fetchRef.current = fetchPage;

  const load = useCallback(async (reset: boolean) => {
    const gen = reset ? ++generation.current : generation.current;
    setState((s) => ({ ...s, loading: true, error: undefined, loadMoreError: undefined }));
    try {
      const page = await fetchRef.current(reset ? undefined : stateRef.current.cursor);
      if (gen !== generation.current) return;
      setState((s) => ({ items: reset ? page.items : [...s.items, ...page.items], cursor: page.cursor, hasMore: page.hasMore, loading: false }));
    } catch (error) {
      if (gen !== generation.current) return;
      setState((s) => (s.items.length && !reset ? { ...s, loading: false, loadMoreError: error } : { items: [], hasMore: false, loading: false, error }));
    }
  }, []);

  useEffect(() => {
    void load(true);
  }, [key, load]);

  const loadMore = useCallback(() => {
    const s = stateRef.current;
    if (s.loading || !s.hasMore || s.error || s.loadMoreError) return;
    void load(false);
  }, [load]);

  return {
    ...state,
    refresh: () => load(true),
    loadMore,
    retry: () => load(stateRef.current.items.length === 0),
    update: (fn: (items: T[]) => T[]) => setState((s) => ({ ...s, items: fn(s.items) })),
  };
}

// Comments ------------------------------------------------------------------------------

export type CommentThread = {
  root: Comment;
  /** Replies and replies to replies, oldest first. */
  replies: Comment[];
  repliesCursor?: unknown;
  repliesLoaded: boolean;
  hasMoreReplies: boolean;
  loadingReplies: boolean;
};

const thread = (root: Comment, repliesLoaded = false): CommentThread => ({
  root,
  replies: [],
  repliesLoaded,
  hasMoreReplies: false,
  loadingReplies: false,
});

/** Comments on one story, a page at a time; replies load per thread on request. */
export function useComments(articleId: number) {
  const uid = useUser()?.uid ?? '';
  const [liked, setLiked] = useState<Set<string>>(new Set());
  const list = useCursorList<CommentThread>(`${articleId}:${uid}`, async (cursor) => {
    const { api } = community();
    const page = await api.comments(articleId, cursor);
    const likes = await api.likedComments(page.items.map((c) => c.id)).catch(() => new Set<string>());
    setLiked((s) => new Set([...(cursor ? s : []), ...likes]));
    return { ...page, items: page.items.map((c) => thread(c)) };
  });
  const { update } = list;

  const updateThread = useCallback(
    (rootId: string, fn: (t: CommentThread) => CommentThread) => update((items) => items.map((t) => (t.root.id === rootId ? fn(t) : t))),
    [update],
  );

  const replace = useCallback(
    (c: Comment) =>
      update((items) =>
        items.map((t) =>
          t.root.id === c.id ? { ...t, root: c } : c.rootId === t.root.id ? { ...t, replies: t.replies.map((r) => (r.id === c.id ? c : r)) } : t,
        ),
      ),
    [update],
  );

  const removeLocal = useCallback(
    (c: Comment) =>
      update((items) =>
        items.filter((t) => t.root.id !== c.id).map((t) => (c.rootId === t.root.id ? { ...t, replies: t.replies.filter((r) => r.id !== c.id) } : t)),
      ),
    [update],
  );

  async function loadReplies(rootId: string) {
    const t = list.items.find((x) => x.root.id === rootId);
    if (!t || t.loadingReplies) return;
    updateThread(rootId, (x) => ({ ...x, loadingReplies: true }));
    const { api } = community();
    try {
      const page = await api.replies(rootId, t.repliesCursor);
      const likes = await api.likedComments(page.items.map((c) => c.id)).catch(() => new Set<string>());
      setLiked((s) => new Set([...s, ...likes]));
      updateThread(rootId, (x) => {
        const seen = new Set(x.replies.map((r) => r.id));
        return {
          ...x,
          replies: [...x.replies, ...page.items.filter((r) => !seen.has(r.id))],
          repliesCursor: page.cursor,
          repliesLoaded: true,
          hasMoreReplies: page.hasMore,
          loadingReplies: false,
        };
      });
    } catch (e) {
      updateThread(rootId, (x) => ({ ...x, loadingReplies: false }));
      throw e;
    }
  }

  /** Posts a comment or a reply. It shows in the list only once it's public (not held for review). */
  async function add(body: string, parent?: Comment): Promise<Comment> {
    const c = await community().api.addComment(articleId, body, parent?.id);
    if (c.status === 'pending') return c;
    if (!c.rootId) {
      update((items) => {
        const pinned = items.filter((t) => t.root.pinned).length;
        return [...items.slice(0, pinned), thread(c, true), ...items.slice(pinned)];
      });
    } else {
      updateThread(c.rootId, (t) => ({
        ...t,
        root: c.parentId === t.root.id ? { ...t.root, replyCount: t.root.replyCount + 1 } : t.root,
        replies: [...t.replies, c],
      }));
    }
    return c;
  }

  async function edit(comment: Comment, body: string): Promise<Comment> {
    const updated = await community().api.editComment(comment.id, body);
    if (updated.status === 'pending') removeLocal(comment);
    else replace(updated);
    return updated;
  }

  async function remove(comment: Comment) {
    await community().api.deleteComment(comment.id);
    if (!comment.rootId && comment.replyCount > 0) {
      // Stays as a placeholder so the replies under it still make sense.
      replace({ ...comment, author: { uid: '', username: '', displayName: 'Deleted' }, body: '', deleted: true });
    } else {
      removeLocal(comment);
    }
  }

  /** Likes or unlikes at once; rolls back if the server refuses. */
  async function toggleLike(comment: Comment) {
    const was = liked.has(comment.id);
    const optimistic = { ...comment, likeCount: Math.max(0, comment.likeCount + (was ? -1 : 1)) };
    replace(optimistic);
    setLiked((s) => {
      const n = new Set(s);
      if (was) n.delete(comment.id);
      else n.add(comment.id);
      return n;
    });
    try {
      const count = await community().api.likeComment(comment.id, !was);
      replace({ ...optimistic, likeCount: count });
    } catch (e) {
      replace(comment);
      setLiked((s) => {
        const n = new Set(s);
        if (was) n.add(comment.id);
        else n.delete(comment.id);
        return n;
      });
      throw e;
    }
  }

  return { ...list, liked, loadReplies, add, edit, remove, toggleLike };
}

// Polls ------------------------------------------------------------------------------------

export function useQuestionOfTheDay() {
  const on = useFeature('questionOfTheDay');
  return useQuery({ queryKey: ['community', 'qotd'], enabled: on, queryFn: () => community().api.questionOfTheDay() });
}

export function useActivePolls() {
  const on = useFeature('polls');
  return useQuery({ queryKey: ['community', 'polls', 'active'], enabled: on, queryFn: () => community().api.activePolls() });
}

export function usePastPolls() {
  const on = useFeature('polls');
  return useQuery({ queryKey: ['community', 'polls', 'past'], enabled: on, queryFn: () => community().api.pastPolls() });
}

/** One poll with the person's vote. Voting updates the results at once and rolls back if it fails. */
export function usePoll(initial: Poll) {
  const uid = useUser()?.uid;
  const [state, setState] = useState<{ poll: Poll; myVote: string | null; voteFor: string | null; busy: boolean }>({ poll: initial, myVote: null, voteFor: null, busy: false });
  const busy = useRef(false);

  useEffect(() => {
    setState((s) => (busy.current ? s : { ...s, poll: initial }));
  }, [initial]);

  useEffect(() => {
    if (!uid) return;
    let alive = true;
    community()
      .api.myVote(initial.id)
      .then(
        (myVote) => alive && !busy.current && setState((s) => ({ ...s, myVote, voteFor: uid })),
        () => {},
      );
    return () => {
      alive = false;
    };
  }, [initial.id, uid]);

  // A vote shows only for the account that cast it.
  const myVote = uid && state.voteFor === uid ? state.myVote : null;
  const open = pollIsOpen(state.poll);
  const hasVoted = myVote !== null;

  async function vote(optionId: string) {
    const before = { ...state, myVote };
    if (busy.current || !open || (hasVoted && !state.poll.allowChange) || myVote === optionId) return;
    busy.current = true;
    setState({ poll: pollWithVote(before.poll, myVote, optionId), myVote: optionId, voteFor: uid ?? null, busy: true });
    try {
      const poll = await community().api.vote(before.poll, optionId);
      setState({ poll, myVote: optionId, voteFor: uid ?? null, busy: false });
    } catch (e) {
      setState({ ...before, busy: false });
      throw e;
    } finally {
      busy.current = false;
    }
  }

  return {
    poll: state.poll,
    busy: state.busy,
    myVote,
    vote,
    hasVoted,
    /** Results show after voting, or once the poll has closed. */
    showResults: hasVoted || !open,
    canVote: open && (!hasVoted || state.poll.allowChange),
  };
}

// Other reads -----------------------------------------------------------------------------------

export function usePublicProfile(uid: string) {
  return useQuery({ queryKey: ['community', 'profile', uid], queryFn: () => community().api.profile(uid) });
}

export function useMySubmissions() {
  const uid = useUser()?.uid;
  return useQuery({ queryKey: ['community', 'submissions', uid], enabled: !!uid, queryFn: () => community().api.mySubmissions(uid!) });
}

/** Category slugs the person follows or picked during onboarding. */
export function useForYouTopics(): string[] {
  const follows = useSession((s) => s.follows);
  const interests = usePreferences((s) => s.interestSlugs);
  return [...new Set([...follows.filter((f) => f.target.kind === 'topic').map((f) => f.target.id), ...interests])].sort();
}

/**
 * "For you": the newest stories in the person's followed and chosen topics.
 * Null when the switch is off or there's nothing to go on, and Home shows
 * the general feed instead of pretending to personalise.
 */
export function useForYou() {
  const on = useFeature('forYou');
  const slugs = useForYouTopics();
  const categories = useCategories();
  const ids = (categories.data ?? []).filter((c) => slugs.includes(c.slug)).map((c) => c.id);
  return useQuery({
    queryKey: ['community', 'for-you', ids],
    enabled: on && ids.length > 0,
    queryFn: async () => {
      const page = await fetchLatest({ perPage: 8, categoryIds: ids });
      return page.items.length ? page.items : null;
    },
  });
}

/** Every startup's name and slug, for spotting mentions. At most a few pages of 50, cached by the HTTP layer. */
function useStartupNames(enabled: boolean) {
  return useQuery({
    queryKey: ['community', 'startup-names'],
    enabled,
    staleTime: 6 * 3600_000,
    queryFn: async () => {
      const all: Startup[] = [];
      try {
        for (let page = 1; page <= 6; page++) {
          const r = await fetchStartups({ sort: 'name' }, page, 50);
          all.push(...r.items);
          if (r.totalPages === undefined || page >= r.totalPages || !r.items.length) break;
        }
      } catch {
        // Whatever loaded is used; the directory may be off.
      }
      return all;
    },
  });
}

export function mentions(text: string, name: string): boolean {
  const n = name.trim();
  if (n.length < 3) return false;
  const escaped = escapeRegExp(n).replace(/\\? /g, '\\s+');
  return new RegExp(`(^|[^\\p{L}\\p{N}])${escaped}($|[^\\p{L}\\p{N}])`, 'iu').test(text);
}

/** Up to three directory startups named in a story (whole words in the title and text). */
export function useMentionedStartups(article: Article): Startup[] {
  const on = useFeature('startupFollows');
  const names = useStartupNames(on);
  if (!on || !names.data?.length) return [];
  const text = `${article.title} ${article.excerpt} ${article.contentHtml ?? ''}`;
  return names.data.filter((s) => mentions(text, s.name)).slice(0, 3);
}
