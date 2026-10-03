import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article.dart';
import '../../core/models/paginated.dart';
import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../../shared/paged_list.dart';

/// A short directory list for a discovery rail (featured, newest...).
final startupRailProvider = FutureProvider.family<List<Startup>, StartupQuery>((
  ref,
  query,
) async {
  final page = await ref
      .watch(startupRepositoryProvider)
      .list(query, perPage: 10);
  return page.items;
});

/// The first page of a directory query, with the total the API reports.
final startupPageProvider =
    FutureProvider.family<Paginated<Startup>, StartupQuery>(
      (ref, query) =>
          ref.watch(startupRepositoryProvider).list(query, perPage: 10),
    );

/// Filter values present in the directory.
final startupFiltersProvider = FutureProvider<StartupFilterOptions>(
  (ref) => ref.watch(startupRepositoryProvider).filters(),
);

final startupProvider = FutureProvider.family<Startup, String>(
  (ref, slug) => ref.watch(startupRepositoryProvider).bySlug(slug),
);

/// Paginated, filtered directory results.
final startupDirectoryProvider =
    NotifierProvider.family<
      PagedListNotifier<Startup>,
      PagedState<Startup>,
      StartupQuery
    >(
      (query) => PagedListNotifier(
        (ref, page, force) => ref
            .read(startupRepositoryProvider)
            .list(query, page: page, forceRefresh: force),
        idOf: (s) => s.id,
      ),
    );

/// AllBioHub stories that mention a startup by name.
///
/// There is no explicit startup↔article relationship in WordPress, so this
/// searches stories for the name and keeps only those whose title or
/// excerpt contains it as a whole word, to avoid loose matches.
final startupCoverageProvider = FutureProvider.family<List<Article>, String>((
  ref,
  name,
) async {
  final results = await ref
      .watch(articleRepositoryProvider)
      .search('"$name"', perPage: 10);
  final pattern = RegExp(
    r'(^|\W)' + RegExp.escape(name) + r'(\W|$)',
    caseSensitive: false,
  );
  return results.items
      .where((a) => pattern.hasMatch(a.title) || pattern.hasMatch(a.excerpt))
      .toList();
});

/// Preset rails on the Startups tab. Each is shown only if it has results.
enum StartupRail {
  featured('Featured startups', StartupQuery(featured: true)),
  recentlyAdded('Recently added', StartupQuery()),
  recentlyVerified(
    'Recently verified',
    StartupQuery(verified: true, sort: StartupSort.verified),
  ),
  recentlyUpdated('Recently updated', StartupQuery(sort: StartupSort.updated));

  const StartupRail(this.title, this.query);

  final String title;
  final StartupQuery query;
}
