import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/models.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../shared/widgets/state_views.dart';
import 'community_lists.dart';
import 'community_widgets.dart';

/// Replies, likes, followed startups and topics, and submission updates,
/// newest first, a page at a time.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  static IconData iconFor(NotificationKind kind) => switch (kind) {
    NotificationKind.commentReply => Icons.reply_rounded,
    NotificationKind.commentLike => Icons.favorite_border_rounded,
    NotificationKind.startupStory => Icons.rocket_launch_outlined,
    NotificationKind.founderStory => Icons.person_outline_rounded,
    NotificationKind.topicStory => Icons.article_outlined,
    NotificationKind.submissionUpdate => Icons.edit_note_rounded,
    NotificationKind.claimUpdate => Icons.verified_outlined,
    NotificationKind.other => Icons.notifications_none_rounded,
  };

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    final uid = ref.read(currentUidProvider);
    if (!n.read && uid != null) {
      ref
          .read(communityApiProvider)
          .markRead(uid, n.id)
          .catchError((Object _) {});
      ref
          .read(notificationsListProvider.notifier)
          .updateWhere(
            (i) => i.id == n.id,
            (i) => AppNotification(
              id: i.id,
              kind: i.kind,
              title: i.title,
              body: i.body,
              url: i.url,
              read: true,
              createdAt: i.createdAt,
            ),
          );
    }
    final url = Uri.tryParse(n.url);
    if (url == null) return;
    final location = url.hasScheme
        ? ref.read(deepLinkParserProvider).locationFor(url)
        : n.url;
    if (location != null) context.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final state = ref.watch(notificationsListProvider);
    final notifier = ref.read(notificationsListProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification preferences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(Routes.notificationSettings),
          ),
          if (user != null && state.items.any((n) => !n.read))
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(communityApiProvider).markAllRead();
                  await notifier.refresh();
                } on Object catch (e) {
                  if (context.mounted) showCommunityError(context, e);
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: user == null
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: JoinPrompt(
                title: 'Your notifications',
                message:
                    'Sign in to hear about replies to your comments and new stories '
                    'about startups and topics you follow.',
              ),
            )
          : RefreshIndicator(
              onRefresh: notifier.refresh,
              child: switch (state) {
                _ when state.isInitialLoading => const Center(
                  child: CircularProgressIndicator(),
                ),
                _ when state.error != null => ListView(
                  children: [
                    ErrorView(error: state.error!, onRetry: notifier.retry),
                  ],
                ),
                _ when state.isEmpty => ListView(
                  children: const [
                    MessageView(
                      icon: Icons.notifications_none_rounded,
                      title: 'Nothing new',
                      message:
                          'Follow startups and topics to hear about new stories. '
                          'Replies to your comments show here too.',
                    ),
                  ],
                ),
                _ => ListView.builder(
                  itemCount: state.items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == state.items.length) {
                      if (state.hasMore &&
                          !state.loading &&
                          state.loadMoreError == null) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => notifier.loadMore(),
                        );
                      }
                      return LoadMoreFooter(
                        isLoading: state.loading || state.hasMore,
                        error: state.loadMoreError,
                        onRetry: notifier.retry,
                      );
                    }
                    final n = state.items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.brand.accentSoft,
                        foregroundColor: context.brand.accentText,
                        child: Icon(iconFor(n.kind), size: 20),
                      ),
                      title: Text(
                        n.title,
                        style: n.read
                            ? null
                            : const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (n.body.isNotEmpty) n.body,
                          relativeDate(n.createdAt),
                        ].join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: n.body.isNotEmpty,
                      trailing: n.read
                          ? null
                          : Icon(
                              Icons.circle,
                              size: 10,
                              color: context.brand.accent,
                            ),
                      onTap: () => _open(context, ref, n),
                    );
                  },
                ),
              },
            ),
    );
  }
}
