import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article.dart';
import '../../core/models/category.dart';
import '../../core/providers.dart';
import '../../core/services/share_service.dart';
import '../../shared/paged_list.dart';

final shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(),
);

final articleByIdProvider = FutureProvider.autoDispose.family<Article, int>(
  (ref, id) => ref.watch(articleRepositoryProvider).byId(id),
);

final articleBySlugProvider = FutureProvider.autoDispose
    .family<Article, String>(
      (ref, slug) => ref.watch(articleRepositoryProvider).bySlug(slug),
    );

final relatedArticlesProvider = FutureProvider.autoDispose
    .family<List<Article>, Article>(
      (ref, article) => ref.watch(articleRepositoryProvider).related(article),
    );

/// Identifies a category or tag feed.
typedef TopicKey = ({TermKind kind, String slug});

final topicProvider = FutureProvider.autoDispose.family<Category, TopicKey>((
  ref,
  key,
) async {
  final repo = ref.watch(taxonomyRepositoryProvider);
  return key.kind == TermKind.category
      ? repo.categoryBySlug(key.slug)
      : repo.tagBySlug(key.slug);
});

/// Stories in a category or tag, paginated.
final topicFeedProvider = NotifierProvider.autoDispose
    .family<PagedListNotifier<Article>, PagedState<Article>, Category>(
      (topic) => PagedListNotifier(
        (ref, page, force) => ref
            .read(articleRepositoryProvider)
            .latest(
              page: page,
              categoryId: topic.kind == TermKind.category ? topic.id : null,
              tagId: topic.kind == TermKind.tag ? topic.id : null,
              forceRefresh: force,
            ),
        idOf: (a) => a.id,
      ),
    );
