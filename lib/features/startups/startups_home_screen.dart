import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/paginated.dart';
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

/// The startup database, laid out like allbiohub.com/startups/: hero with
/// search, stats, browse by industry, the sortable list, browse by country
/// and the "Building something in Africa?" call to action. Featured startups
/// get a rail when the website marks any.
class StartupsHomeScreen extends ConsumerWidget {
  const StartupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(startupFiltersProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(startupRailProvider);
          ref.invalidate(startupPageProvider);
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
              AsyncData(:final value) => _content(value),
              _ => [
                const SliverToBoxAdapter(
                  child: Skeleton(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SkeletonBox(height: 260, radius: 20),
                          SizedBox(height: 16),
                          SkeletonBox(height: 72, radius: 14),
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

  List<Widget> _content(StartupFilterOptions filters) => [
    const SliverToBoxAdapter(child: _Hero()),
    SliverToBoxAdapter(child: _Stats(filters: filters)),
    const SliverToBoxAdapter(child: _FeaturedRail()),
    SliverToBoxAdapter(
      child: _BrowseBy(
        title: 'Browse by industry',
        options: filters.industries,
        toQuery: (v) => StartupQuery(industry: v),
      ),
    ),
    const SliverToBoxAdapter(child: _AllStartups()),
    SliverToBoxAdapter(
      child: _BrowseBy(
        title: 'Browse by country',
        options: filters.countries,
        toQuery: (v) => StartupQuery(country: v),
      ),
    ),
    const SliverToBoxAdapter(child: _BuildingCta()),
    const SliverToBoxAdapter(child: SizedBox(height: 32)),
  ];
}

Uri _site(WidgetRef ref, String path) =>
    Uri.parse(ref.watch(appConfigProvider).siteUrl).replace(path: path);

/// "Discover African Startups", the search box and the two website actions.
class _Hero extends ConsumerWidget {
  const _Hero();

  // Brand purple in both themes so the white text keeps its contrast.
  static const _top = Color(0xFF4F3DAD);
  static const _bottom = Color(0xFF2B2066);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_top, _bottom],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Discover African Startups',
                style: text.headlineMedium?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore startups, founders, products and emerging companies '
              'across Africa.',
              style: text.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            TextField(
              textInputAction: TextInputAction.search,
              style: text.bodyLarge?.copyWith(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search startups',
                hintStyle: text.bodyMedium?.copyWith(color: Colors.black45),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.black54,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                final q = value.trim();
                context.push(
                  Routes.startupDirectory,
                  extra: StartupQuery(search: q.isEmpty ? null : q),
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _bottom,
                  ),
                  onPressed: () =>
                      openLink(context, ref, _site(ref, '/list-your-startup/')),
                  child: const Text('List Your Startup'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () =>
                      openLink(context, ref, _site(ref, '/claim-startup/')),
                  child: const Text('Claim Your Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Startups, Verified, Countries, Industries: counts from the API only.
class _Stats extends ConsumerWidget {
  const _Stats({required this.filters});

  final StartupFilterOptions filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(startupPageProvider(const StartupQuery()));
    final verified = ref.watch(
      startupPageProvider(const StartupQuery(verified: true)),
    );
    int? total(AsyncValue<Paginated<Startup>> page) {
      final value = page.value;
      if (value == null) return null;
      return value.total ?? (value.hasMore ? null : value.items.length);
    }

    final stats = [
      ('Startups', total(all)),
      ('Verified', total(verified)),
      ('Countries', filters.countries.length),
      ('Industries', filters.industries.length),
    ];
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          for (final (i, (label, value)) in stats.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: brand.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: brand.border),
                ),
                child: Semantics(
                  label: '$label: ${value ?? 'loading'}',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Text(
                        value == null ? '–' : _compact(value),
                        style: context.text.titleLarge?.copyWith(
                          color: brand.accentText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: context.text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _compact(int n) =>
      n >= 10000 ? '${(n / 1000).toStringAsFixed(0)}k' : n.toString();
}

/// Featured startups, only when the website marks some as featured.
class _FeaturedRail extends ConsumerWidget {
  const _FeaturedRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = StartupRail.featured.query;
    final items = ref.watch(startupRailProvider(query)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: StartupRail.featured.title,
          onViewAll: () => context.push(Routes.startupDirectory, extra: query),
        ),
        StartupRailList(startups: items),
      ],
    );
  }
}

/// Tiles for each industry or country, with how many startups it has.
class _BrowseBy extends StatelessWidget {
  const _BrowseBy({
    required this.title,
    required this.options,
    required this.toQuery,
  });

  final String title;
  final List<FilterOption> options;
  final StartupQuery Function(String value) toQuery;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final o in options.take(12))
                    SizedBox(
                      width: width,
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
                            extra: toQuery(o.value),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.label,
                                  style: context.text.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (o.count != null)
                                  Text(
                                    o.count == 1
                                        ? '1 startup'
                                        : '${o.count} startups',
                                    style: context.text.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The directory list with the website's sort options and filters.
class _AllStartups extends ConsumerStatefulWidget {
  const _AllStartups();

  @override
  ConsumerState<_AllStartups> createState() => _AllStartupsState();
}

class _AllStartupsState extends ConsumerState<_AllStartups> {
  StartupSort _sort = StartupSort.newest;

  @override
  Widget build(BuildContext context) {
    final query = StartupQuery(sort: _sort);
    final page = ref.watch(startupPageProvider(query));
    final total = page.value?.total;
    void openDirectory() => context.push(Routes.startupDirectory, extra: query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'All startups',
          subtitle: total == null ? null : _count(total),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<StartupSort>(
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    isDense: true,
                  ),
                  items: [
                    for (final s in StartupSort.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (s) {
                    if (s != null) setState(() => _sort = s);
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: openDirectory,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Filters'),
              ),
            ],
          ),
        ),
        ...switch (page) {
          AsyncData(:final value) when value.items.isEmpty => [
            const _NoStartupsYet(),
          ],
          AsyncData(:final value) => [
            for (final s in value.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: StartupCard(startup: s),
              ),
            if (value.hasMore || (total ?? 0) > value.items.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: openDirectory,
                    child: Text(
                      total == null
                          ? 'See all startups'
                          : 'See all ${_count(total)}',
                    ),
                  ),
                ),
              ),
          ],
          AsyncError(:final error) when !page.isLoading => [
            ErrorView(
              compact: true,
              error: error,
              onRetry: () => ref.invalidate(startupPageProvider(query)),
            ),
          ],
          _ => [
            const Skeleton(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SkeletonBox(height: 170, radius: 16),
                    SizedBox(height: 10),
                    SkeletonBox(height: 170, radius: 16),
                  ],
                ),
              ),
            ),
          ],
        },
      ],
    );
  }

  static String _count(int n) => n == 1 ? '1 startup' : '$n startups';
}

/// The website answered but listed no startups for the app.
class _NoStartupsYet extends ConsumerWidget {
  const _NoStartupsYet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      const MessageView(
        compact: true,
        icon: Icons.rocket_launch_rounded,
        title: 'No startups to show yet',
        message:
            "The directory hasn't shared any startups with the app yet. "
            'You can browse them on allbiohub.com.',
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          onPressed: () =>
              openLink(context, ref, _site(ref, '/startups/'), inApp: false),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Browse startups on allbiohub.com'),
        ),
      ),
    ],
  );
}

/// "Building something in Africa?" with the website's three actions.
class _BuildingCta extends ConsumerWidget {
  const _BuildingCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dark in both themes, so it takes the dark accents.
    const brand = BrandColors.dark;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111114),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.rocket_launch_rounded, color: brand.highlight, size: 30),
            const SizedBox(height: 12),
            Text(
              'Building something in Africa?',
              style: text.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your startup to the AllBioHub directory, claim your '
              'profile and get verified.',
              style: text.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () =>
                      openLink(context, ref, _site(ref, '/list-your-startup/')),
                  child: const Text('List Your Startup'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () =>
                      openLink(context, ref, _site(ref, '/claim-startup/')),
                  child: const Text('Claim Your Startup'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: brand.accentText,
                  ),
                  onPressed: () =>
                      openLink(context, ref, _site(ref, '/startup-pricing/')),
                  child: const Text('Get Verified →'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown until the website exposes the startup directory API.
class _DirectoryUnavailable extends ConsumerWidget {
  const _DirectoryUnavailable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onPressed: () =>
                openLink(context, ref, _site(ref, '/startups/'), inApp: false),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Browse startups on allbiohub.com'),
          ),
        ),
        const _BuildingCta(),
      ],
    );
  }
}
