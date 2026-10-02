import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../../core/repositories/startup_repository.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/link_opener.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import 'startup_providers.dart';
import 'startup_widgets.dart';

/// Startup discovery hub: rails, browse-by dimensions and directory actions.
class StartupsHomeScreen extends ConsumerWidget {
  const StartupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(startupFiltersProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(startupRailProvider);
          ref.invalidate(startupFiltersProvider);
          await ref
              .read(startupFiltersProvider.future)
              .catchError((Object _) => const StartupFilterOptions());
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: 20,
              title: Text('Startups', style: context.text.headlineSmall),
            ),
            ...switch (filters) {
              AsyncError(:final error)
                  when error is StartupDirectoryUnavailable =>
                [const SliverToBoxAdapter(child: _DirectoryUnavailable())],
              AsyncError(:final error) when !filters.isLoading => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(startupFiltersProvider),
                  ),
                ),
              ],
              AsyncData(:final value) => _content(context, value),
              _ => [
                const SliverToBoxAdapter(
                  child: Skeleton(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SkeletonBox(height: 52, radius: 14),
                          SizedBox(height: 24),
                          SkeletonBox(height: 200, radius: 16),
                          SizedBox(height: 24),
                          SkeletonBox(height: 200, radius: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, StartupFilterOptions filters) {
    final browse = [
      (
        'Explore by industry',
        filters.industries,
        (String v) => StartupQuery(industry: v),
      ),
      (
        'Explore by country',
        filters.countries,
        (String v) => StartupQuery(country: v),
      ),
      (
        'Explore by stage',
        filters.stages,
        (String v) => StartupQuery(stage: v),
      ),
      (
        'Explore by funding',
        filters.fundings,
        (String v) => StartupQuery(funding: v),
      ),
    ];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: _DirectorySearchLauncher(),
        ),
      ),
      for (final rail in StartupRail.values)
        SliverToBoxAdapter(child: _Rail(rail: rail)),
      for (final (title, options, toQuery) in browse)
        if (options.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: title),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in options.take(16))
                        ActionChip(
                          label: Text(
                            o.count == null
                                ? o.label
                                : '${o.label} · ${o.count}',
                          ),
                          onPressed: () => context.push(
                            Routes.startupDirectory,
                            extra: toQuery(o.value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      const SliverToBoxAdapter(child: _DirectoryActions()),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

class _DirectorySearchLauncher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: brand.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: brand.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(
                Routes.startupDirectory,
                extra: const StartupQuery(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: brand.muted),
                    const SizedBox(width: 12),
                    Text(
                      'Search startups',
                      style: context.text.bodyMedium?.copyWith(
                        color: brand.subtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'Browse all with filters',
          onPressed: () => context.push(
            Routes.startupDirectory,
            extra: const StartupQuery(),
          ),
          icon: const Icon(Icons.tune_rounded),
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
        ),
      ],
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.rail});

  final StartupRail rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startups = ref.watch(startupRailProvider(rail.query));
    final items = startups.value;
    // Only rails with real data are shown.
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: rail.title,
          onViewAll: () =>
              context.push(Routes.startupDirectory, extra: rail.query),
        ),
        StartupRailList(startups: items),
      ],
    );
  }
}

class _DirectoryActions extends ConsumerWidget {
  const _DirectoryActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = Uri.parse(ref.watch(appConfigProvider).siteUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          _ActionCard(
            icon: Icons.add_business_rounded,
            title: 'List your startup',
            body: 'Add your company to the AllBioHub directory.',
            onTap: () => openLink(
              context,
              ref,
              site.replace(path: '/list-your-startup/'),
            ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.how_to_reg_rounded,
            title: 'Claim your startup',
            body: 'Manage your profile and become eligible for verification.',
            onTap: () =>
                openLink(context, ref, site.replace(path: '/claim-startup/')),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: brand.goldSoft,
          child: Icon(icon, color: brand.goldText),
        ),
        title: Text(title),
        subtitle: Text(body),
        trailing: Tooltip(
          message: 'Opens on allbiohub.com',
          child: Icon(Icons.open_in_new_rounded, size: 18, color: brand.muted),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Shown until the website exposes the startup directory API.
class _DirectoryUnavailable extends ConsumerWidget {
  const _DirectoryUnavailable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = Uri.parse(ref.watch(appConfigProvider).siteUrl);
    return Column(
      children: [
        const MessageView(
          icon: Icons.rocket_launch_rounded,
          title: 'The startup directory is on its way',
          message:
              "Searching and filtering African startups in the app is coming soon. "
              'Meanwhile you can browse the full directory on allbiohub.com.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilledButton.icon(
            onPressed: () => openLink(
              context,
              ref,
              site.replace(path: '/startups/'),
              inApp: false,
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Browse startups on allbiohub.com'),
          ),
        ),
        const _DirectoryActions(),
      ],
    );
  }
}
