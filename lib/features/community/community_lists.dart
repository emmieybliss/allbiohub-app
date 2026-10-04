import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/models/article.dart';
import '../../core/models/category.dart';
import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../home/home_providers.dart';

typedef CursorFetcher<T> = Future<CursorPage<T>> Function(
  Ref ref,
  Object? cursor,
);

class CursorListState<T> {
  const CursorListState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.error,
    this.loadMoreError,
  });

  final List<T> items;
  final Object? cursor;
  final bool hasMore;
  final bool loading;
  final Object? error;
  final Object? loadMoreError;

  bool get isInitialLoading => loading && items.isEmpty;
  bool get isEmpty => !loading && error == null && items.isEmpty;
}

/// A list loaded a page at a time from a cursor-paginated collection
/// (notifications, a person's comments).
class CursorListNotifier<T> extends Notifier<CursorListState<T>> {
  CursorListNotifier(this._fetch);

  final CursorFetcher<T> _fetch;
  int _generation = 0;

  @override
  CursorListState<T> build() {
    Future.microtask(() => _load(reset: true));
    return CursorListState<T>(loading: true);
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.error != null) return;
    await _load(reset: false);
  }

  Future<void> retry() => _load(reset: state.items.isEmpty);

  /// Replaces items in place (e.g. marking a notification read).
  void updateWhere(bool Function(T) test, T Function(T) update) {
    state = CursorListState(
      items: [for (final i in state.items) test(i) ? update(i) : i],
      cursor: state.cursor,
      hasMore: state.hasMore,
    );
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    state = CursorListState(
      items: state.items,
      cursor: state.cursor,
      hasMore: state.hasMore,
      loading: true,
    );
    try {
      final page = await _fetch(ref, reset ? null : state.cursor);
      if (!ref.mounted || generation != _generation) return;
      state = CursorListState(
        items: [if (!reset) ...state.items, ...page.items],
        cursor: page.cursor,
        hasMore: page.hasMore,
      );
    } on Object catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.items.isEmpty
          ? CursorListState(error: e, hasMore: false)
          : CursorListState(
              items: state.items,
              cursor: state.cursor,
              hasMore: state.hasMore,
              loadMoreError: e,
            );
    }
  }
}

final notificationsListProvider =
    NotifierProvider.autoDispose<
      CursorListNotifier<AppNotification>,
      CursorListState<AppNotification>
    >(
      () => CursorListNotifier((ref, cursor) {
        final uid = ref.read(currentUidProvider);
        if (uid == null) {
          return Future.value(const CursorPage([], hasMore: false));
        }
        return ref
            .read(communityApiProvider)
            .notifications(uid, cursor: cursor);
      }),
    );

final myCommentsProvider =
    NotifierProvider.autoDispose<
      CursorListNotifier<Comment>,
      CursorListState<Comment>
    >(
      () => CursorListNotifier((ref, cursor) {
        final uid = ref.read(currentUidProvider);
        if (uid == null) {
          return Future.value(const CursorPage([], hasMore: false));
        }
        return ref.read(communityApiProvider).commentsBy(uid, cursor: cursor);
      }),
    );

final mySubmissionsProvider = FutureProvider.autoDispose<List<Submission>>((
  ref,
) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  return ref.watch(communityApiProvider).mySubmissions(uid);
});

/// Category slugs the person follows (or picked during onboarding).
final forYouTopicsProvider = Provider<Set<String>>((ref) {
  final follows = ref.watch(followsProvider).value ?? const [];
  return {
    for (final f in follows)
      if (f.target.kind == FollowKind.topic) f.target.id,
    ...ref.watch(preferencesProvider.select((p) => p.interestSlugs)),
  };
});

/// "For You": the newest stories in the person's followed topics. Null
/// when the switch is off or there aren't enough signals yet, and Home
/// shows the general feed instead of pretending to personalize.
final forYouProvider = FutureProvider<List<Article>?>((ref) async {
  if (!ref.watch(featureProvider(Feature.forYou))) return null;
  final slugs = ref.watch(forYouTopicsProvider);
  if (slugs.isEmpty) return null;
  final categories = await ref.watch(categoriesProvider.future);
  final ids = [
    for (final c in categories)
      if (slugs.contains(c.slug)) c.id,
  ];
  if (ids.isEmpty) return null;
  final page = await ref
      .watch(articleRepositoryProvider)
      .latest(perPage: 8, categoryIds: ids);
  return page.items.isEmpty ? null : page.items;
});

/// Startups in the directory whose names appear in a story, matched as
/// whole words in the title and text (the same rule as a startup's
/// AllBioHub coverage). Empty when the directory isn't available.
final mentionedStartupsProvider = FutureProvider.autoDispose
    .family<List<Startup>, Article>((ref, article) async {
      final names = await ref.watch(startupNamesProvider.future);
      if (names.isEmpty) return const [];
      final text =
          '${article.title} ${article.excerpt} ${article.contentHtml ?? ''}';
      final matches = names.where((s) => _mentions(text, s.name)).take(3);
      return matches.toList();
    });

/// Every startup's name and slug, for spotting mentions. Cached for hours
/// by the API client; at most a few pages of 50.
final startupNamesProvider = FutureProvider<List<Startup>>((ref) async {
  final repo = ref.watch(startupRepositoryProvider);
  final all = <Startup>[];
  try {
    for (var page = 1; page <= 6; page++) {
      final result = await repo.list(
        const StartupQuery(sort: StartupSort.name),
        page: page,
        perPage: 50,
      );
      all.addAll(result.items);
      if (!result.hasMore) break;
    }
  } on Object {
    return all;
  }
  return all;
});

bool _mentions(String text, String name) {
  final n = name.trim();
  if (n.length < 3) return false;
  final escaped = RegExp.escape(n).replaceAll(r'\ ', r'\s+');
  return RegExp(
    '(^|[^\\p{L}\\p{N}])$escaped(\$|[^\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(text);
}

/// The person's followed startups, topics or founders, newest first.
final followsOfKindProvider = Provider.family<List<FollowedItem>, FollowKind>(
  (ref, kind) => [
    for (final f in ref.watch(followsProvider).value ?? const <FollowedItem>[])
      if (f.target.kind == kind) f,
  ],
);

/// Topic follow target for a category.
FollowTarget topicTarget(Category c) =>
    FollowTarget(FollowKind.topic, c.slug, label: c.displayName);
