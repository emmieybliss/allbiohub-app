import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/models.dart';
import '../../core/providers.dart';
import '../../core/services/analytics_service.dart';

/// A top-level comment with the replies loaded under it so far.
class CommentThread {
  const CommentThread({
    required this.root,
    this.replies = const [],
    this.repliesCursor,
    this.repliesLoaded = false,
    this.hasMoreReplies = false,
    this.loadingReplies = false,
  });

  final Comment root;

  /// Replies and replies to replies, oldest first.
  final List<Comment> replies;
  final Object? repliesCursor;
  final bool repliesLoaded;
  final bool hasMoreReplies;
  final bool loadingReplies;

  CommentThread copyWith({
    Comment? root,
    List<Comment>? replies,
    Object? repliesCursor,
    bool? repliesLoaded,
    bool? hasMoreReplies,
    bool? loadingReplies,
  }) => CommentThread(
    root: root ?? this.root,
    replies: replies ?? this.replies,
    repliesCursor: repliesCursor ?? this.repliesCursor,
    repliesLoaded: repliesLoaded ?? this.repliesLoaded,
    hasMoreReplies: hasMoreReplies ?? this.hasMoreReplies,
    loadingReplies: loadingReplies ?? this.loadingReplies,
  );
}

class CommentsState {
  const CommentsState({
    this.threads = const [],
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.error,
    this.loadMoreError,
    this.liked = const {},
  });

  final List<CommentThread> threads;
  final Object? cursor;
  final bool hasMore;
  final bool loading;

  /// The first page failed (nothing to show).
  final Object? error;

  /// A later page failed (what's loaded stays).
  final Object? loadMoreError;

  /// Comments the person liked.
  final Set<String> liked;

  bool get isInitialLoading => loading && threads.isEmpty;

  CommentsState copyWith({
    List<CommentThread>? threads,
    Object? cursor,
    bool? hasMore,
    bool? loading,
    Object? error,
    Object? loadMoreError,
    Set<String>? liked,
  }) => CommentsState(
    threads: threads ?? this.threads,
    cursor: cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    error: error,
    loadMoreError: loadMoreError,
    liked: liked ?? this.liked,
  );
}

/// Comments on one article, loaded a page at a time. Replies load per
/// thread on request. Never loads everything at once.
class CommentsNotifier extends Notifier<CommentsState> {
  CommentsNotifier(this.articleId);

  final int articleId;
  static const pageSize = 20;
  int _generation = 0;

  @override
  CommentsState build() {
    ref.watch(currentUidProvider);
    Future.microtask(() => _load(reset: true));
    return const CommentsState(loading: true);
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.error != null) return;
    await _load(reset: false);
  }

  Future<void> retry() => _load(reset: state.threads.isEmpty);

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    state = state.copyWith(loading: true);
    final api = ref.read(communityApiProvider);
    try {
      final page = await api.comments(
        articleId,
        cursor: reset ? null : state.cursor,
        limit: pageSize,
      );
      final liked = await api
          .likedComments(page.items.map((c) => c.id))
          .catchError((Object _) => <String>{});
      if (!ref.mounted || generation != _generation) return;
      final existing = reset ? <CommentThread>[] : state.threads;
      final seen = {for (final t in existing) t.root.id};
      state = CommentsState(
        threads: [
          ...existing,
          for (final c in page.items)
            if (seen.add(c.id)) CommentThread(root: c),
        ],
        cursor: page.cursor,
        hasMore: page.hasMore,
        liked: {if (!reset) ...state.liked, ...liked},
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.threads.isEmpty
          ? CommentsState(error: e, hasMore: false)
          : state.copyWith(loading: false, loadMoreError: e);
    }
  }

  void _updateThread(String rootId, CommentThread Function(CommentThread) f) {
    state = state.copyWith(
      threads: [for (final t in state.threads) t.root.id == rootId ? f(t) : t],
    );
  }

  Future<void> loadReplies(String rootId) async {
    final thread = state.threads.where((t) => t.root.id == rootId).firstOrNull;
    if (thread == null || thread.loadingReplies) return;
    _updateThread(rootId, (t) => t.copyWith(loadingReplies: true));
    final api = ref.read(communityApiProvider);
    try {
      final page = await api.replies(rootId, cursor: thread.repliesCursor);
      final liked = await api
          .likedComments(page.items.map((c) => c.id))
          .catchError((Object _) => <String>{});
      if (!ref.mounted) return;
      _updateThread(rootId, (t) {
        final seen = {for (final r in t.replies) r.id};
        return CommentThread(
          root: t.root,
          replies: [...t.replies, ...page.items.where((r) => seen.add(r.id))],
          repliesCursor: page.cursor,
          repliesLoaded: true,
          hasMoreReplies: page.hasMore,
        );
      });
      state = state.copyWith(liked: {...state.liked, ...liked});
    } on Object {
      if (ref.mounted) {
        _updateThread(rootId, (t) => t.copyWith(loadingReplies: false));
      }
      rethrow;
    }
  }

  /// Posts a comment, or a reply to [parent]. Returns the stored comment;
  /// it appears in the list only once it's public (not held for review).
  Future<Comment> add(String body, {Comment? parent}) async {
    final comment = await ref
        .read(communityApiProvider)
        .addComment(articleId, body, parentId: parent?.id);
    unawaited(
      ref.read(analyticsProvider).log(AnalyticsEvent.articleComment, {
        'article_id': articleId,
        'reply': parent == null ? 0 : 1,
      }),
    );
    if (!ref.mounted || comment.isPending) return comment;
    if (comment.rootId == null) {
      final pinned = state.threads.takeWhile((t) => t.root.pinned).toList();
      state = state.copyWith(
        threads: [
          ...pinned,
          CommentThread(root: comment, repliesLoaded: true),
          ...state.threads.skip(pinned.length),
        ],
      );
    } else {
      _updateThread(
        comment.rootId!,
        (t) => t.copyWith(
          root: comment.parentId == t.root.id
              ? t.root.copyWith(replyCount: t.root.replyCount + 1)
              : t.root,
          replies: [...t.replies, comment],
        ),
      );
    }
    return comment;
  }

  void _replace(Comment updated) {
    state = state.copyWith(
      threads: [
        for (final t in state.threads)
          if (t.root.id == updated.id)
            t.copyWith(root: updated)
          else if (updated.rootId == t.root.id)
            t.copyWith(
              replies: [
                for (final r in t.replies) r.id == updated.id ? updated : r,
              ],
            )
          else
            t,
      ],
    );
  }

  Future<Comment> edit(Comment comment, String body) async {
    final updated = await ref
        .read(communityApiProvider)
        .editComment(comment.id, body);
    if (!ref.mounted) return updated;
    if (updated.isPending) {
      _remove(comment);
    } else {
      _replace(updated);
    }
    return updated;
  }

  void _remove(Comment comment) {
    state = state.copyWith(
      threads: [
        for (final t in state.threads)
          if (t.root.id != comment.id)
            comment.rootId == t.root.id
                ? t.copyWith(
                    replies: t.replies
                        .where((r) => r.id != comment.id)
                        .toList(),
                  )
                : t,
      ],
    );
  }

  Future<void> delete(Comment comment) async {
    await ref.read(communityApiProvider).deleteComment(comment.id);
    if (!ref.mounted) return;
    if (comment.rootId == null && comment.replyCount > 0) {
      // Stays as a placeholder so the replies under it still make sense.
      _replace(
        Comment(
          id: comment.id,
          articleId: comment.articleId,
          author: const CommentAuthor(
            uid: '',
            username: '',
            displayName: 'Deleted',
          ),
          body: '',
          createdAt: comment.createdAt,
          deleted: true,
          replyCount: comment.replyCount,
        ),
      );
    } else {
      _remove(comment);
    }
  }

  /// Likes or unlikes at once; rolls back if the server refuses.
  Future<void> toggleLike(Comment comment) async {
    final liked = state.liked.contains(comment.id);
    final before = state;
    final updated = comment.copyWith(
      likeCount: (comment.likeCount + (liked ? -1 : 1)).clamp(0, 1 << 30),
    );
    _replace(updated);
    state = state.copyWith(
      liked: liked
          ? ({...state.liked}..remove(comment.id))
          : {...state.liked, comment.id},
    );
    try {
      final count = await ref
          .read(communityApiProvider)
          .likeComment(comment.id, like: !liked);
      if (ref.mounted) _replace(updated.copyWith(likeCount: count));
      if (!liked) {
        unawaited(
          ref.read(analyticsProvider).log(AnalyticsEvent.commentLike, {
            'article_id': articleId,
          }),
        );
      }
    } on Object {
      if (ref.mounted) state = before;
      rethrow;
    }
  }
}

final commentsProvider = NotifierProvider.autoDispose
    .family<CommentsNotifier, CommentsState, int>(CommentsNotifier.new);
