import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/models/article.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import 'comments_screen.dart';
import 'community_lists.dart';
import 'community_widgets.dart';
import 'reaction_bar.dart';

/// Reactions, topic and startup follows, and the way into comments, shown
/// under a story. Each part appears only when its feature is switched on,
/// so with everything off the reader looks exactly as before.
class ArticleCommunitySection extends ConsumerWidget {
  const ArticleCommunitySection({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool on(Feature f) => ref.watch(featureProvider(f));
    final topic = article.primaryCategory;
    final startups = on(Feature.startupFollows)
        ? ref.watch(mentionedStartupsProvider(article)).value ?? const []
        : const [];
    final children = <Widget>[
      if (on(Feature.reactions)) ReactionBar(articleId: article.id),
      if (topic != null && on(Feature.topicFollows))
        _Row(
          icon: Icons.article_outlined,
          title: 'More on ${topic.displayName}',
          subtitle: 'Hear when AllBioHub publishes a new story on this topic.',
          trailing: FollowButton(target: topicTarget(topic), dense: true),
        ),
      if (startups.isNotEmpty) ...[
        Text('Interested in this startup?', style: context.text.titleSmall),
        for (final s in startups)
          _Row(
            icon: Icons.rocket_launch_outlined,
            title: s.name,
            subtitle: 'Get alerts when AllBioHub covers ${s.name}.',
            onTap: () => context.push(Routes.startup(s.slug)),
            trailing: FollowButton(
              target: FollowTarget(FollowKind.startup, s.slug, label: s.name),
              dense: true,
            ),
          ),
      ],
      if (on(Feature.comments))
        CommentsEntry(
          articleId: article.id,
          title: htmlToPlainText(article.title),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            c,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.brand.accentSoft,
            foregroundColor: context.brand.accentText,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
