import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/models.dart';
import '../../core/community/saved.dart';
import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/article_cards.dart';
import '../startups/startup_providers.dart';
import 'community_widgets.dart';

/// What the startup profile knows about a founder, passed when opening
/// their page. The directory has no separate founder records, so a page
/// opened from a follow or a saved item shows the name and coverage only.
class FounderArgs {
  const FounderArgs({required this.founder, this.startup});

  final Founder founder;
  final Startup? startup;
}

/// A founder: follow for new stories, save, share, and AllBioHub coverage.
class FounderScreen extends ConsumerWidget {
  const FounderScreen({super.key, required this.slug, this.args});

  final String slug;
  final FounderArgs? args;

  String _name(WidgetRef ref) {
    if (args != null) return args!.founder.name;
    final followed = ref
        .watch(followsProvider)
        .value
        ?.where(
          (f) => f.target.kind == FollowKind.founder && f.target.id == slug,
        )
        .firstOrNull;
    if (followed != null && followed.target.label.isNotEmpty) {
      return followed.target.label;
    }
    final saved = ref
        .watch(savedEntitiesProvider)
        .where((e) => e.kind == SavedKind.founder && e.id == slug)
        .firstOrNull;
    if (saved != null) return saved.title;
    return slug
        .split('-')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _name(ref);
    final founder = args?.founder;
    final startup = args?.startup;
    final coverage = ref.watch(startupCoverageProvider(name));
    final subtitle = [
      if (founder?.role != null && founder!.role!.isNotEmpty) founder.role!,
      if (startup != null) startup.name,
    ].join(' · ');
    final site = ref.watch(appConfigProvider).siteUrl;

    return Scaffold(
      appBar: AppBar(
        actions: [
          SaveEntityButton(
            entity: SavedEntity(
              kind: SavedKind.founder,
              id: slug,
              title: name,
              subtitle: subtitle.isEmpty ? null : subtitle,
              url: founder?.profileUrl,
            ),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              ref.read(analyticsProvider).log(AnalyticsEvent.founderShare, {
                'id': slug,
              });
              SharePlus.instance.share(
                ShareParams(
                  text: [
                    subtitle.isEmpty ? name : '$name, $subtitle',
                    if (startup != null) startup.link else site,
                  ].join('\n'),
                  subject: name,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: context.brand.accentSoft,
                  foregroundColor: context.brand.accentText,
                  child: Text(
                    name
                        .split(' ')
                        .where((w) => w.isNotEmpty)
                        .take(2)
                        .map((w) => w[0].toUpperCase())
                        .join(),
                    style: context.text.titleLarge?.copyWith(
                      color: context.brand.accentText,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.text.headlineSmall),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: context.text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FollowButton(
                  target: FollowTarget(FollowKind.founder, slug, label: name),
                ),
                if (startup != null)
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.startup(startup.slug)),
                    icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                    label: Text(startup.name),
                  ),
                if (founder?.profileUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(founder!.profileUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Profile'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('On AllBioHub', style: context.text.titleLarge),
          ),
          switch (coverage) {
            AsyncData(value: final articles) when articles.isEmpty => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No AllBioHub stories mention $name yet.',
                style: context.text.bodyMedium,
              ),
            ),
            AsyncData(value: final articles) => Column(
              children: [for (final a in articles) ArticleListTile(article: a)],
            ),
            AsyncError() => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Stories could not be loaded.',
                style: context.text.bodyMedium,
              ),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}
