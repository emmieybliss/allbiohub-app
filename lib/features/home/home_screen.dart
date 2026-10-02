import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/article.dart';
import '../../core/models/category.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import '../startups/startup_providers.dart';
import '../startups/startup_widgets.dart';
import 'home_providers.dart';

/// The editorial front page.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(categoryPreviewProvider);
    ref.invalidate(startupRailProvider);
    await Future.wait([
      ref.read(homeFeedProvider.notifier).refresh(),
      ref.read(moreStoriesProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        edgeOffset: 100,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              titleSpacing: 20,
              title: const Wordmark(),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => context.push(Routes.search),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => context.push(Routes.notificationSettings),
                ),
                const SizedBox(width: 8),
              ],
            ),
            ...switch (feed) {
              AsyncData(:final value) => _content(context, value),
              AsyncError(:final error) when !feed.isLoading => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(homeFeedProvider),
                  ),
                ),
              ],
              _ => [const SliverToBoxAdapter(child: HomeSkeleton())],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, HomeFeed feed) {
    if (feed.featured.isEmpty && feed.latest.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: MessageView(
            icon: Icons.article_outlined,
            title: 'No stories yet',
            message: 'Check back soon for the latest from AllBioHub.',
          ),
        ),
      ];
    }
    final top = feed.latest.take(5).toList();
    final rest = feed.latest.skip(5).toList();
    final shownIds = {
      ...feed.featured.map((a) => a.id),
      ...feed.latest.map((a) => a.id),
    };
    return [
      if (feed.stale) const SliverToBoxAdapter(child: OfflineBanner()),
      SliverToBoxAdapter(child: _FeaturedCarousel(articles: feed.featured)),
      const SliverToBoxAdapter(child: SectionHeader(title: 'Latest stories')),
      SliverList.list(
        children: [for (final a in top) ArticleListTile(article: a)],
      ),
      const _CategorySections(start: 0, count: 2),
      const SliverToBoxAdapter(child: _StartupsSection()),
      const _CategorySections(start: 2, count: 4),
      if (rest.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader(title: 'More to read')),
        SliverList.list(
          children: [for (final a in rest) ArticleListTile(article: a)],
        ),
      ],
      _MoreStories(excludeIds: shownIds),
    ];
  }
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.articles});

  final List<Article> articles;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articles = widget.articles;
    if (articles.isEmpty) return const SizedBox.shrink();
    final height = (MediaQuery.sizeOf(context).width * 1.05).clamp(
      340.0,
      460.0,
    );
    if (articles.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: ArticleHeroCard(article: articles.first, height: height),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            itemCount: articles.length,
            padEnds: false,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? 20 : 6, right: 6),
              child: ArticleHeroCard(article: articles[i], height: height),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < articles.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? context.brand.accent
                        : context.brand.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rails for a slice of the categories list.
class _CategorySections extends ConsumerWidget {
  const _CategorySections({required this.start, required this.count});

  final int start;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final slice = categories.skip(start).take(count).toList();
    return SliverList.list(
      children: [for (final c in slice) _CategoryRail(category: c)],
    );
  }
}

class _CategoryRail extends ConsumerWidget {
  const _CategoryRail({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(categoryPreviewProvider(category.id));
    // A rail that fails or is empty is simply left out; Home stays usable.
    final items = stories.value;
    if (stories.hasError && items == null) return const SizedBox.shrink();
    if (items != null && items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: category.displayName,
          onViewAll: () =>
              context.push(Routes.category(category.slug), extra: category),
        ),
        SizedBox(
          height: ArticleRailCard.railHeight(context),
          child: items == null
              ? Skeleton(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, _) => const SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 156, radius: 16),
                          SizedBox(height: 12),
                          SkeletonBox(width: 70, height: 10),
                          SizedBox(height: 8),
                          SkeletonBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => ArticleRailCard(article: items[i]),
                ),
        ),
      ],
    );
  }
}

class _StartupsSection extends ConsumerWidget {
  const _StartupsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startups = ref
        .watch(startupRailProvider(StartupRail.featured.query))
        .value;
    final fallback = ref
        .watch(startupRailProvider(StartupRail.recentlyAdded.query))
        .value;
    final list = (startups != null && startups.isNotEmpty)
        ? startups
        : fallback;
    if (list == null || list.isEmpty) {
      // No directory data in the app yet: point to the Startups tab.
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: StartupDirectoryPromo(onTap: () => context.go(Routes.startups)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Explore African startups',
          onViewAll: () => context.go(Routes.startups),
        ),
        StartupRailList(startups: list),
      ],
    );
  }
}

/// Endless list at the bottom of Home. Loads its first page only once it
/// scrolls into view.
class _MoreStories extends ConsumerWidget {
  const _MoreStories({required this.excludeIds});

  final Set<int> excludeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moreStoriesProvider);
    final notifier = ref.read(moreStoriesProvider.notifier);
    final items = state.items.where((a) => !excludeIds.contains(a.id)).toList();
    // Loading changes provider state, which can't happen during build.
    void loadMoreSoon() => WidgetsBinding.instance.addPostFrameCallback(
      (_) => notifier.loadMore(),
    );
    return SliverMainAxisGroup(
      slivers: [
        if (items.isNotEmpty)
          const SliverToBoxAdapter(child: SectionHeader(title: 'Keep reading')),
        SliverList.builder(
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i < items.length) {
              if (i == items.length - 3) loadMoreSoon();
              return ArticleListTile(article: items[i]);
            }
            if (state.hasMore &&
                !state.isLoading &&
                state.loadMoreError == null &&
                state.error == null) {
              loadMoreSoon();
            }
            if (state.error != null) {
              return LoadMoreFooter(
                isLoading: false,
                error: state.error,
                onRetry: notifier.retry,
              );
            }
            return LoadMoreFooter(
              isLoading: state.isLoading || state.hasMore,
              error: state.loadMoreError,
              onRetry: notifier.retry,
            );
          },
        ),
      ],
    );
  }
}
