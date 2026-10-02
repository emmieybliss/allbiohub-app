import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../../core/repositories/startup_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/link_opener.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import '../articles/article_providers.dart';
import 'startup_providers.dart';
import 'startup_widgets.dart';

/// A startup's profile, with AllBioHub coverage of it.
class StartupProfileScreen extends ConsumerStatefulWidget {
  const StartupProfileScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<StartupProfileScreen> createState() =>
      _StartupProfileScreenState();
}

class _StartupProfileScreenState extends ConsumerState<StartupProfileScreen> {
  bool _logged = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(startupProvider(widget.slug));
    final site = Uri.parse(ref.watch(appConfigProvider).siteUrl);
    final webUrl = site.replace(path: '/startups/${widget.slug}/');

    if (async.value case final startup? when !_logged) {
      _logged = true;
      ref.read(analyticsProvider).log(AnalyticsEvent.startupView, {
        'slug': startup.slug,
      });
    }

    return switch (async) {
      AsyncData(:final value) => Scaffold(body: _Profile(startup: value)),
      AsyncError(:final error) when !async.isLoading => Scaffold(
        appBar: AppBar(),
        body: error is StartupDirectoryUnavailable
            ? MessageView(
                icon: Icons.rocket_launch_rounded,
                title: 'Open this startup on allbiohub.com',
                message: 'Startup profiles are coming to the app soon.',
                actionLabel: 'View profile',
                onAction: () => openLink(context, ref, webUrl, inApp: false),
              )
            : ErrorView(
                error: error,
                onRetry: () => ref.invalidate(startupProvider(widget.slug)),
              ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Skeleton(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 76, height: 76, radius: 20),
                SizedBox(height: 16),
                SkeletonBox(width: 200, height: 24),
                SizedBox(height: 12),
                SkeletonBox(height: 14),
                SizedBox(height: 8),
                SkeletonBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    };
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.startup});

  final Startup startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.brand;
    final site = Uri.parse(ref.watch(appConfigProvider).siteUrl);
    final facts = <(IconData, String, String?)>[
      (Icons.category_outlined, 'Industry', startup.industry),
      (Icons.public_rounded, 'Country', startup.country),
      (Icons.location_city_rounded, 'City', startup.city),
      (Icons.event_outlined, 'Founded', startup.foundedYear?.toString()),
      (Icons.trending_up_rounded, 'Stage', startup.stage),
      (Icons.payments_outlined, 'Funding', startup.funding),
      (Icons.storefront_outlined, 'Business model', startup.businessModel),
      (Icons.groups_outlined, 'Employees', startup.employees),
      (Icons.radio_button_checked_rounded, 'Status', startup.status),
    ].where((f) => f.$3 != null).toList();

    Future<void> share() async {
      final shared = await ref.read(shareServiceProvider).shareStartup(startup);
      if (shared) {
        ref.read(analyticsProvider).log(AnalyticsEvent.startupShare, {
          'slug': startup.slug,
        });
      }
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(startup.name),
          actions: [
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: share,
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StartupLogo(startup: startup, size: 76),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        startup.name,
                        style: context.text.headlineLarge,
                      ),
                    ),
                    if (startup.verified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        color: brand.verified,
                        semanticLabel: 'Verified',
                      ),
                    ],
                  ],
                ),
                if (startup.tagline != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    startup.tagline!,
                    style: context.text.bodyLarge?.copyWith(color: brand.muted),
                  ),
                ],
                const SizedBox(height: 12),
                StartupBadges(startup: startup, showClaimed: true),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (startup.website != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              _openWebsite(context, ref, startup.website!),
                          icon: const Icon(Icons.language_rounded),
                          label: const Text('Visit website'),
                        ),
                      ),
                    if (startup.website != null) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: share,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
                if (startup.description != null &&
                    startup.description != startup.tagline) ...[
                  const SizedBox(height: 28),
                  Text('About', style: context.text.titleLarge),
                  const SizedBox(height: 8),
                  Text(startup.description!, style: context.text.bodyLarge),
                ],
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Company details', style: context.text.titleLarge),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final (i, (icon, label, value))
                            in facts.indexed) ...[
                          if (i > 0) const Divider(indent: 56),
                          ListTile(
                            dense: true,
                            leading: Icon(icon),
                            title: Text(label, style: context.text.bodySmall),
                            subtitle: Text(
                              value!,
                              style: context.text.titleSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (startup.founders.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Founders', style: context.text.titleLarge),
                  const SizedBox(height: 4),
                  for (final f in startup.founders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: brand.accentSoft,
                        child: Text(
                          f.name.isEmpty ? '?' : f.name[0],
                          style: TextStyle(color: brand.accentText),
                        ),
                      ),
                      title: Text(f.name),
                      subtitle: f.role == null ? null : Text(f.role!),
                      trailing: f.profileUrl == null
                          ? null
                          : const Icon(Icons.open_in_new_rounded, size: 18),
                      onTap: f.profileUrl == null
                          ? null
                          : () => openLink(
                              context,
                              ref,
                              Uri.parse(f.profileUrl!),
                            ),
                    ),
                ],
                if (startup.products.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Products', style: context.text.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in startup.products) Chip(label: Text(p)),
                    ],
                  ),
                ],
                if (startup.socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Social', style: context.text.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in startup.socialLinks.entries)
                        ActionChip(
                          label: Text(_socialLabel(e.key)),
                          onPressed: () => _openWebsite(context, ref, e.value),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        _Coverage(startup: startup),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: startup.claimed
                ? OutlinedButton.icon(
                    onPressed: () => openLink(
                      context,
                      ref,
                      site.replace(path: '/claim-startup/'),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Suggest an update'),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Is this your startup?',
                            style: context.text.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Claim this profile to keep it accurate and become eligible for verification.',
                            style: context.text.bodyMedium?.copyWith(
                              color: brand.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () => openLink(
                              context,
                              ref,
                              site.replace(path: '/claim-startup/'),
                            ),
                            child: const Text('Claim this startup'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  static String _socialLabel(String key) => switch (key.toLowerCase()) {
    'linkedin' => 'LinkedIn',
    'twitter' || 'x' => 'X',
    'facebook' => 'Facebook',
    'instagram' => 'Instagram',
    'youtube' => 'YouTube',
    'tiktok' => 'TikTok',
    'github' => 'GitHub',
    _ => key,
  };

  void _openWebsite(BuildContext context, WidgetRef ref, String url) {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null) openLink(context, ref, uri, inApp: false);
  }
}

class _Coverage extends ConsumerWidget {
  const _Coverage({required this.startup});

  final Startup startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage =
        ref.watch(startupCoverageProvider(startup.name)).value ?? const [];
    if (coverage.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: SectionHeader(
            title: 'AllBioHub coverage',
            subtitle: 'Stories that mention this startup',
          ),
        ),
        SliverList.list(
          children: [for (final a in coverage) ArticleListTile(article: a)],
        ),
      ],
    );
  }
}
