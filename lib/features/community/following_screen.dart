import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/models/media_image.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../shared/widgets/app_image.dart';
import '../../shared/widgets/state_views.dart';
import '../startups/startup_providers.dart';
import 'community_lists.dart';
import 'community_widgets.dart';

/// Profile → Following: startups, topics and founders, each with an
/// Unfollow button.
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = [
      if (ref.watch(featureProvider(Feature.startupFollows)))
        FollowKind.startup,
      if (ref.watch(featureProvider(Feature.topicFollows))) FollowKind.topic,
      if (ref.watch(featureProvider(Feature.founderFollows)))
        FollowKind.founder,
    ];
    if (kinds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: const MessageView(
          icon: Icons.favorite_border_rounded,
          title: 'Following is coming soon',
          message: 'You will be able to follow startups, topics and founders.',
        ),
      );
    }
    return DefaultTabController(
      length: kinds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Following'),
          bottom: TabBar(
            tabs: [
              for (final k in kinds)
                Tab(
                  text: switch (k) {
                    FollowKind.startup => 'Startups',
                    FollowKind.topic => 'Topics',
                    FollowKind.founder => 'Founders',
                  },
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final k in kinds) _FollowList(kind: k)],
        ),
      ),
    );
  }
}

class _FollowList extends ConsumerWidget {
  const _FollowList({required this.kind});

  final FollowKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(followsProvider);
    final items = ref.watch(followsOfKindProvider(kind));
    if (follows.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return MessageView(
        icon: Icons.add_circle_outline_rounded,
        title: switch (kind) {
          FollowKind.startup => 'No startups yet',
          FollowKind.topic => 'No topics yet',
          FollowKind.founder => 'No founders yet',
        },
        message: switch (kind) {
          FollowKind.startup =>
            'Tap Follow on a startup profile to get news about it.',
          FollowKind.topic =>
            'Tap Follow on a topic to hear about new stories.',
          FollowKind.founder =>
            'Tap Follow on a founder to hear about new stories.',
        },
        actionLabel: kind == FollowKind.topic ? null : 'Explore startups',
        onAction: kind == FollowKind.topic
            ? null
            : () => context.go(Routes.startups),
      );
    }
    if (kind == FollowKind.startup) return _Watchlist(items: items);
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = items[i];
        return ListTile(
          leading: Icon(
            kind == FollowKind.topic
                ? Icons.tag_rounded
                : Icons.person_outline_rounded,
          ),
          title: Text(item.label),
          onTap: () => context.push(
            kind == FollowKind.topic
                ? Routes.category(item.target.id)
                : Routes.founder(item.target.id),
          ),
          trailing: FollowButton(target: item.target, dense: true),
        );
      },
    );
  }
}

/// My Startup Watchlist: followed startups with their industry, country,
/// stage and latest AllBioHub story, as far as the directory has them.
class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(followsOfKindProvider(FollowKind.startup));
    return Scaffold(
      appBar: AppBar(title: const Text('My Startup Watchlist')),
      body: items.isEmpty
          ? MessageView(
              icon: Icons.rocket_launch_outlined,
              title: 'Your watchlist is empty',
              message: 'Follow startups to keep track of them here.',
              actionLabel: 'Explore startups',
              onAction: () => context.go(Routes.startups),
            )
          : _Watchlist(items: items),
    );
  }
}

class _Watchlist extends StatelessWidget {
  const _Watchlist({required this.items});

  final List<FollowedItem> items;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: items.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, i) => _WatchlistTile(item: items[i]),
  );
}

class _WatchlistTile extends ConsumerWidget {
  const _WatchlistTile({required this.item});

  final FollowedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupProvider(item.target.id)).value;
    final latest = ref.watch(startupCoverageProvider(item.label)).value;
    final details = [
      startup?.industry,
      startup?.country,
      startup?.stage,
    ].whereType<String>().join(' · ');
    final logo =
        startup?.logo ??
        (item.image == null ? null : MediaImage.single(item.image!));
    return InkWell(
      onTap: () => context.push(Routes.startup(item.target.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: logo == null
                    ? ColoredBox(
                        color: context.brand.accentSoft,
                        child: Icon(
                          Icons.rocket_launch_outlined,
                          color: context.brand.accentText,
                        ),
                      )
                    : AppImage(image: logo, allowCropped: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    startup?.name ?? item.label,
                    style: context.text.titleMedium,
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(details, style: context.text.bodySmall),
                  ],
                  if (latest != null && latest.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => context.push(
                        Routes.article(latest.first.id),
                        extra: latest.first,
                      ),
                      child: Text(
                        'Latest: ${latest.first.title} · ${relativeDate(latest.first.publishedAt)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: context.brand.accentText,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            FollowButton(target: item.target, dense: true),
          ],
        ),
      ),
    );
  }
}

/// The person's own comments, newest first, including ones awaiting review.
class MyCommentsScreen extends ConsumerWidget {
  const MyCommentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCommentsProvider);
    final notifier = ref.read(myCommentsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('My comments')),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: switch (state) {
          _ when state.isInitialLoading => const Center(
            child: CircularProgressIndicator(),
          ),
          _ when state.error != null => ListView(
            children: [ErrorView(error: state.error!, onRetry: notifier.retry)],
          ),
          _ when state.isEmpty => ListView(
            children: const [
              MessageView(
                icon: Icons.forum_outlined,
                title: 'No comments yet',
                message: 'Your comments on stories will show here.',
              ),
            ],
          ),
          _ => ListView.separated(
            itemCount: state.items.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
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
              final c = state.items[i];
              final status = c.deleted
                  ? 'Deleted'
                  : switch (c.status) {
                      ModerationStatus.pending => 'Awaiting review',
                      ModerationStatus.rejected => 'Not published',
                      ModerationStatus.removed => 'Removed',
                      ModerationStatus.approved => null,
                    };
              return ListTile(
                title: Text(
                  c.deleted ? 'Deleted comment' : c.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    relativeDate(c.createdAt),
                    ?status,
                    if (c.likeCount > 0) '${c.likeCount} likes',
                  ].join(' · '),
                ),
                onTap: () => context.push(Routes.articleComments(c.articleId)),
              );
            },
          ),
        },
      ),
    );
  }
}

/// Another person's public profile, with Report and Block.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_profileProvider(uid));
    final me = ref.watch(currentUidProvider);
    final blocked =
        ref.watch(blockedUsersProvider).value?.contains(uid) ?? false;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (me != null && me != uid)
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'report') {
                  await _report(context, ref);
                } else {
                  try {
                    await ref
                        .read(communityApiProvider)
                        .setBlocked(uid, blocked: !blocked);
                    if (context.mounted) {
                      showMessage(
                        context,
                        blocked
                            ? 'Unblocked'
                            : 'Blocked. Their comments are hidden.',
                      );
                    }
                  } on Object catch (e) {
                    if (context.mounted) showCommunityError(context, e);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'report', child: Text('Report')),
                PopupMenuItem(
                  value: 'block',
                  child: Text(blocked ? 'Unblock' : 'Block'),
                ),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncData(value: final p?) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [ProfileHeader(profile: p)],
        ),
        AsyncData() => const MessageView(
          icon: Icons.lock_outline_rounded,
          title: 'This profile is private',
          message:
              'Only their name and username are shown with their comments.',
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(_profileProvider(uid)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          .report(targetType: 'user', targetId: uid, reason: reason);
      if (context.mounted) {
        showMessage(context, 'Thanks. Our moderators will review it.');
      }
    } on Object catch (e) {
      if (context.mounted) showCommunityError(context, e);
    }
  }
}

final _profileProvider = FutureProvider.autoDispose
    .family<UserProfile?, String>(
      (ref, uid) => ref.watch(communityApiProvider).profile(uid),
    );

/// Picture, name, @username, bio, joined date and counts. Shows only
/// public profile fields, never email or ids.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, this.isMe = false});

  final UserProfile profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final joined = profile.joinedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              name: profile.displayName,
              photoUrl: profile.photoUrl,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName, style: context.text.titleLarge),
                  Text(
                    '@${profile.username}',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.brand.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(profile.bio, style: context.text.bodyLarge),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (joined != null)
              Text(
                'Joined AllBioHub ${_monthYear(joined)}',
                style: context.text.bodySmall,
              ),
            if (isMe || profile.showActivity) ...[
              Text(
                '${profile.followingCount} following',
                style: context.text.bodySmall,
              ),
              Text(
                '${profile.commentCount} ${profile.commentCount == 1 ? 'comment' : 'comments'}',
                style: context.text.bodySmall,
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _monthYear(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}
