import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/category.dart';
import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import '../home/home_providers.dart';
import '../search/search_screen.dart';
import '../startups/startup_providers.dart';
import '../startups/startup_widgets.dart';

final popularTagsProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(taxonomyRepositoryProvider).popularTags(),
);

/// Icon for a website category, by slug. Unknown categories get a default.
IconData categoryIcon(String slug) => switch (slug) {
  'biography' => Icons.person_search_rounded,
  'celebrity-news' => Icons.star_rounded,
  'around-the-web' => Icons.public_rounded,
  'startup-founders-innovator' => Icons.rocket_launch_rounded,
  'reviews' => Icons.rate_review_rounded,
  'money-career' => Icons.payments_rounded,
  'women-in-tech' => Icons.memory_rounded,
  _ when slug.contains('tech') => Icons.memory_rounded,
  _ when slug.contains('spotlight') => Icons.flare_rounded,
  _ => Icons.article_rounded,
};

/// Discovery hub: search, every category, topics, people and startups.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  /// Website categories that feature people, shown as rails when present.
  static const _peopleRails = {
    'biography': 'People to know',
    'startup-founders-innovator': 'Founders & innovators',
    'women-in-tech': 'Women in tech',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final tags = ref.watch(popularTagsProvider).value ?? const [];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(popularTagsProvider);
          ref.invalidate(categoryPreviewProvider);
          ref.invalidate(categoriesProvider);
          await ref
              .read(categoriesProvider.future)
              .catchError((Object _) => <Category>[]);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: 20,
              title: Text('Discover', style: context.text.headlineSmall),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: SearchLauncher(),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Explore by topic',
                subtitle: 'Every section on AllBioHub',
              ),
            ),
            switch (categories) {
              AsyncData(:final value) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 104,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: value.length,
                  itemBuilder: (_, i) => _CategoryTile(category: value[i]),
                ),
              ),
              AsyncError(:final error) when !categories.isLoading =>
                SliverToBoxAdapter(
                  child: ErrorView(
                    error: error,
                    compact: true,
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                ),
              _ => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Skeleton(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SkeletonBox(height: 104, radius: 16),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: SkeletonBox(height: 104, radius: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SkeletonBox(height: 104, radius: 16),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: SkeletonBox(height: 104, radius: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            },
            if (tags.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Popular topics'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tags)
                        ActionChip(
                          label: Text('#${t.name}'),
                          onPressed: () =>
                              context.push(Routes.tag(t.slug), extra: t),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: _StartupDiscovery()),
            for (final category in categories.value ?? const <Category>[])
              if (_peopleRails.containsKey(category.slug))
                SliverToBoxAdapter(
                  child: _PeopleRail(
                    category: category,
                    title: _peopleRails[category.slug]!,
                  ),
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Material(
      color: brand.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: brand.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(Routes.category(category.slug), extra: category),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                categoryIcon(category.slug),
                color: brand.goldText,
                size: 26,
              ),
              const Spacer(),
              Text(
                category.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              Text('${category.count} stories', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleRail extends ConsumerWidget {
  const _PeopleRail({required this.category, required this.title});

  final Category category;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(categoryPreviewProvider(category.id)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          onViewAll: () =>
              context.push(Routes.category(category.slug), extra: category),
        ),
        SizedBox(
          height: 286,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) =>
                ArticleRailCard(article: items[i], width: 220),
          ),
        ),
      ],
    );
  }
}

/// Startup entry points: industries from the directory when it's available,
/// otherwise a link to the Startups tab.
class _StartupDiscovery extends ConsumerWidget {
  const _StartupDiscovery();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(startupFiltersProvider).value;
    final industries = filters?.industries ?? const <FilterOption>[];
    if (industries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: StartupDirectoryPromo(onTap: () => context.go(Routes.startups)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Startups by industry',
          onViewAll: () => context.go(Routes.startups),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in industries.take(12))
                ActionChip(
                  label: Text(
                    i.count == null ? i.label : '${i.label} · ${i.count}',
                  ),
                  onPressed: () => context.push(
                    Routes.startupDirectory,
                    extra: StartupQuery(industry: i.value),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
