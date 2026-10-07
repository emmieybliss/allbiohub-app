import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../shared/widgets/state_views.dart';
import 'comments_providers.dart';
import 'community_widgets.dart';
import 'reactions_providers.dart';

/// "Comments · Join the conversation" block at the end of a story. Shows
/// the real comment count and opens the full conversation.
class CommentsEntry extends ConsumerWidget {
  const CommentsEntry({super.key, required this.articleId, this.title});

  final int articleId;

  /// The story's title, shown above the comments.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureProvider(Feature.comments))) {
      return const SizedBox.shrink();
    }
    final count = ref.watch(
      reactionProvider(articleId).select((s) => s.engagement.commentCount),
    );
    final me = ref.watch(myProfileProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Comments', style: context.text.titleLarge),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$count',
                style: context.text.titleMedium?.copyWith(
                  color: context.brand.muted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: context.brand.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.brand.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () =>
                context.push(Routes.articleComments(articleId), extra: title),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  UserAvatar(
                    name: me?.displayName,
                    photoUrl: me?.photoUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      count == 0
                          ? 'Join the conversation'
                          : 'Read and join the conversation',
                      style: context.text.bodyLarge?.copyWith(
                        color: context.brand.muted,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The full conversation on a story: comments a page at a time, replies on
/// request, and a composer at the bottom.
class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.articleId, this.title});

  final int articleId;
  final String? title;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  Comment? _editing;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  CommentsNotifier get _notifier =>
      ref.read(commentsProvider(widget.articleId).notifier);

  void _startReply(Comment comment) {
    setState(() {
      _replyTo = comment;
      _editing = null;
    });
    _focus.requestFocus();
  }

  void _startEdit(Comment comment) {
    setState(() {
      _editing = comment;
      _replyTo = null;
      _input.text = comment.body;
    });
    _focus.requestFocus();
  }

  void _clearTarget() => setState(() {
    _replyTo = null;
    if (_editing != null) _input.clear();
    _editing = null;
  });

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    if (!await requireAccount(
      context,
      ref,
      verified: true,
      reason: 'Sign in to join the conversation.',
    )) {
      return;
    }
    setState(() => _sending = true);
    try {
      final Comment result;
      if (_editing != null) {
        result = await _notifier.edit(_editing!, body);
      } else {
        result = await _notifier.add(body, parent: _replyTo);
      }
      _input.clear();
      _focus.unfocus();
      setState(() {
        _replyTo = null;
        _editing = null;
      });
      if (result.isPending && mounted) {
        showMessage(context, 'Thanks. Your comment will appear after review.');
      }
    } on Object catch (e) {
      // The text stays in the box so nothing is lost.
      if (mounted) showCommunityError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like(Comment comment) async {
    if (!await requireAccount(context, ref, profile: false)) return;
    try {
      await _notifier.toggleLike(comment);
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    }
  }

  Future<void> _delete(Comment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _notifier.delete(comment);
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    }
  }

  Future<void> _report(Comment comment) async {
    if (!await requireAccount(context, ref, profile: false)) return;
    if (!mounted) return;
    await showReportSheet(
      context,
      ref,
      targetType: 'comment',
      targetId: comment.id,
    );
  }

  Future<void> _block(Comment comment) async {
    if (!await requireAccount(context, ref, profile: false)) return;
    try {
      await ref
          .read(communityApiProvider)
          .setBlocked(comment.author.uid, blocked: true);
      if (mounted) {
        showMessage(
          context,
          "You won't see @${comment.author.username}'s comments.",
        );
      }
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    }
  }

  void _actions(Comment comment) {
    final mine = comment.author.uid == ref.read(currentUidProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _startEdit(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _delete(comment);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report comment'),
                onTap: () {
                  Navigator.pop(context);
                  _report(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text('Block @${comment.author.username}'),
                onTap: () {
                  Navigator.pop(context);
                  _block(comment);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsProvider(widget.articleId));
    final blocked = ref.watch(blockedUsersProvider).value ?? const <String>{};
    final threads = [
      for (final t in state.threads)
        if (!blocked.contains(t.root.author.uid) || t.root.deleted) t,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _notifier.refresh,
              child: switch (state) {
                _ when state.isInitialLoading => const Center(
                  child: CircularProgressIndicator(),
                ),
                _ when state.error != null => ListView(
                  children: [
                    ErrorView(error: state.error!, onRetry: _notifier.retry),
                  ],
                ),
                _ when threads.isEmpty => ListView(
                  children: const [
                    MessageView(
                      icon: Icons.forum_outlined,
                      title: 'No comments yet',
                      message: 'Start the conversation about this story.',
                    ),
                  ],
                ),
                _ => ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: threads.length + 1,
                  itemBuilder: (context, i) {
                    if (i == threads.length) {
                      if (state.hasMore &&
                          !state.loading &&
                          state.loadMoreError == null) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _notifier.loadMore(),
                        );
                      }
                      return LoadMoreFooter(
                        isLoading: state.loading || state.hasMore,
                        error: state.loadMoreError,
                        onRetry: _notifier.retry,
                      );
                    }
                    return _Thread(
                      thread: threads[i],
                      liked: state.liked,
                      blocked: blocked,
                      onReply: _startReply,
                      onLike: _like,
                      onMore: _actions,
                      onLoadReplies: () => _notifier
                          .loadReplies(threads[i].root.id)
                          .catchError((Object e) {
                            if (context.mounted) showCommunityError(context, e);
                          }),
                    );
                  },
                ),
              },
            ),
          ),
          _Composer(
            controller: _input,
            focus: _focus,
            sending: _sending,
            replyTo: _replyTo,
            editing: _editing != null,
            onCancel: _clearTarget,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.thread,
    required this.liked,
    required this.blocked,
    required this.onReply,
    required this.onLike,
    required this.onMore,
    required this.onLoadReplies,
  });

  final CommentThread thread;
  final Set<String> liked;
  final Set<String> blocked;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment> onMore;
  final VoidCallback onLoadReplies;

  @override
  Widget build(BuildContext context) {
    final replies = [
      for (final r in thread.replies)
        if (!blocked.contains(r.author.uid)) r,
    ];
    final unseen = thread.root.replyCount > 0 && !thread.repliesLoaded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentTile(
          comment: thread.root,
          liked: liked.contains(thread.root.id),
          onReply: onReply,
          onLike: onLike,
          onMore: onMore,
        ),
        for (final r in replies)
          CommentTile(
            comment: r,
            liked: liked.contains(r.id),
            onReply: onReply,
            onLike: onLike,
            onMore: onMore,
          ),
        if (unseen || thread.hasMoreReplies)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: TextButton(
              onPressed: thread.loadingReplies ? null : onLoadReplies,
              child: Text(
                thread.loadingReplies
                    ? 'Loading replies…'
                    : unseen
                    ? 'View ${thread.root.replyCount} ${thread.root.replyCount == 1 ? 'reply' : 'replies'}'
                    : 'More replies',
              ),
            ),
          ),
        const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }
}

/// One comment: picture, name, @username, time, text, likes and Reply.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.liked,
    required this.onReply,
    required this.onLike,
    required this.onMore,
  });

  final Comment comment;
  final bool liked;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment> onMore;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final indent = 20.0 + comment.depth * 32.0;
    if (comment.deleted) {
      return Padding(
        padding: EdgeInsets.fromLTRB(indent, 14, 20, 14),
        child: Text(
          'This comment was deleted.',
          style: context.text.bodyMedium?.copyWith(
            color: brand.muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final author = comment.author;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 14, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: author.uid.isEmpty
                ? null
                : () => context.push(Routes.userProfile(author.uid)),
            child: UserAvatar(
              name: author.displayName,
              photoUrl: author.photoUrl,
              size: comment.depth == 0 ? 36 : 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(author.displayName, style: context.text.titleSmall),
                    if (author.username.isNotEmpty)
                      Text(
                        '@${author.username}',
                        style: context.text.bodySmall,
                      ),
                    Text(
                      '· ${relativeDate(comment.createdAt)}${comment.editedAt != null ? ' · edited' : ''}',
                      style: context.text.bodySmall,
                    ),
                    if (comment.pinned)
                      Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: brand.accentText,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (comment.isPending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Awaiting review · only you can see this',
                      style: context.text.labelSmall?.copyWith(
                        color: brand.accentText,
                      ),
                    ),
                  ),
                Text.rich(
                  TextSpan(
                    children: [
                      if (comment.replyToUsername != null && comment.depth >= 2)
                        TextSpan(
                          text: '@${comment.replyToUsername} ',
                          style: TextStyle(
                            color: brand.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      TextSpan(text: comment.body),
                    ],
                  ),
                  style: context.text.bodyLarge,
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: liked ? brand.accentText : brand.muted,
                      ),
                      onPressed: () => onLike(comment),
                      icon: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                      ),
                      label: Text(
                        comment.likeCount > 0 ? '${comment.likeCount}' : 'Like',
                        semanticsLabel:
                            '${liked ? 'Unlike' : 'Like'}, ${comment.likeCount} likes',
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: brand.muted,
                      ),
                      onPressed: () => onReply(comment),
                      child: const Text('Reply'),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'More',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.more_horiz_rounded, color: brand.muted),
                      onPressed: () => onMore(comment),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.sending,
    required this.replyTo,
    required this.editing,
    required this.onCancel,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final Comment? replyTo;
  final bool editing;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final label = editing
        ? 'Editing your comment'
        : replyTo != null
        ? 'Replying to @${replyTo!.author.username}'
        : null;
    return Material(
      elevation: 8,
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Row(
                  children: [
                    Expanded(child: Text(label, style: context.text.bodySmall)),
                    IconButton(
                      tooltip: 'Cancel',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onCancel,
                    ),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: editing ? 'Save' : 'Post',
                    onPressed: sending ? null : onSend,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            editing ? Icons.check_rounded : Icons.send_rounded,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks why, then reports a comment or person to the moderators.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text("What's wrong?", style: context.text.titleLarge),
          ),
          for (final r in ReportReason.values)
            ListTile(
              title: Text(r.label),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    ),
  );
  if (reason == null) return;
  try {
    await ref
        .read(communityApiProvider)
        .report(targetType: targetType, targetId: targetId, reason: reason);
    if (context.mounted) {
      showMessage(context, 'Thanks. Our moderators will review it.');
    }
  } on Object catch (e) {
    if (context.mounted) showCommunityError(context, e);
  }
}
