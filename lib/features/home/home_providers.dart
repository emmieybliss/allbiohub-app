import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article.dart';
import '../../core/models/category.dart';
import '../../core/providers.dart';
import '../../shared/paged_list.dart';

/// Editorial categories from the website, ordered by the person's interests
/// first and then by size.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final categories = await ref.watch(taxonomyRepositoryProvider).categories();
  final interests = ref.watch(
    preferencesProvider.select((p) => p.interestSlugs),
  );
  if (interests.isEmpty) return categories;
  return [
    ...categories.where((c) => interests.contains(c.slug)),
    ...categories.where((c) => !interests.contains(c.slug)),
  ];
});

class HomeFeed {
  const HomeFeed({
    required this.featured,
    required this.latest,
    this.stale = false,
  });

  /// Lead stories: sticky posts if editors pinned any, else the newest.
  final List<Article> featured;
  final List<Article> latest;
  final bool stale;
}

/// Top of Home: featured stories and the latest list.
class HomeFeedNotifier extends AsyncNotifier<HomeFeed> {
  @override
  Future<HomeFeed> build() => _load(forceRefresh: false);

  /// Pull-to-refresh: bypasses the cache and keeps current stories on
  /// screen until the new ones arrive (or the offline cache is used).
  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => _load(forceRefresh: true));
    if (ref.mounted) state = next;
  }

  Future<HomeFeed> _load({required bool forceRefresh}) async {
    final repo = ref.read(articleRepositoryProvider);
    // Start both requests together; sticky posts are optional.
    final stickyFuture = repo
        .featured(forceRefresh: forceRefresh)
        .catchError((Object _) => <Article>[]);
    final latestPage = await repo.latest(
      perPage: homeLatestCount,
      forceRefresh: forceRefresh,
    );
    final sticky = await stickyFuture;
    final latest = latestPage.items;
    final featured = sticky.isNotEmpty
        ? sticky.take(3).toList()
        : latest.take(3).toList();
    final featuredIds = {for (final a in featured) a.id};
    return HomeFeed(
      featured: featured,
      latest: latest.where((a) => !featuredIds.contains(a.id)).toList(),
      stale: latestPage.stale,
    );
  }
}

final homeFeedProvider = AsyncNotifierProvider<HomeFeedNotifier, HomeFeed>(
  HomeFeedNotifier.new,
);

/// A few recent stories for a category rail on Home.
final categoryPreviewProvider = FutureProvider.family<List<Article>, int>((
  ref,
  categoryId,
) async {
  final page = await ref
      .watch(articleRepositoryProvider)
      .latest(perPage: 6, categoryId: categoryId);
  return page.items;
});

const homeLatestCount = 12;

/// "More stories" infinite list below the Home sections. Continues after the
/// first [homeLatestCount] stories that the top of Home already shows.
final moreStoriesProvider =
    NotifierProvider<PagedListNotifier<Article>, PagedState<Article>>(
      () => PagedListNotifier(
        (ref, page, force) => ref
            .read(articleRepositoryProvider)
            .latest(
              page: page + 1,
              perPage: homeLatestCount,
              forceRefresh: force,
            ),
        idOf: (a) => a.id,
        autoLoad: false,
      ),
    );
