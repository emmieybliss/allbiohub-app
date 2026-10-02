import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/paginated.dart';

typedef PageFetcher<T> = Future<Paginated<T>> Function(
  Ref ref,
  int page,
  bool forceRefresh,
);

/// State of an infinitely scrolling list.
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
    this.loadMoreError,
    this.stale = false,
  });

  final List<T> items;

  /// Last page loaded (0 before the first load).
  final int page;
  final bool hasMore;
  final bool isLoading;

  /// Failure loading the first page (nothing to show).
  final Object? error;

  /// Failure loading a later page (existing items stay visible).
  final Object? loadMoreError;

  /// Items came from the offline cache.
  final bool stale;

  bool get isInitialLoading => isLoading && items.isEmpty;
  bool get isEmpty => !isLoading && error == null && items.isEmpty;
  bool get isLoadingMore => isLoading && items.isNotEmpty;
}

/// Loads pages on demand, one request at a time, and de-duplicates items
/// that shift between pages when new stories are published mid-scroll.
class PagedListNotifier<T> extends Notifier<PagedState<T>> {
  PagedListNotifier(this._fetch, {required this._idOf, this.autoLoad = true});

  final PageFetcher<T> _fetch;
  final Object Function(T item) _idOf;

  /// When false the first page waits for [loadMore], e.g. a list at the
  /// bottom of a screen that loads only once scrolled into view.
  final bool autoLoad;
  int _generation = 0;

  @override
  PagedState<T> build() {
    if (!autoLoad) return const PagedState();
    Future.microtask(() => _load(1, force: false));
    return const PagedState(isLoading: true);
  }

  Future<void> refresh() =>
      state.page == 0 && !autoLoad ? Future.value() : _load(1, force: true);

  Future<void> loadMore() async {
    final s = state;
    if (s.isLoading || !s.hasMore || s.error != null) return;
    await _load(s.page + 1, force: false);
  }

  Future<void> retry() => state.items.isEmpty
      ? _load(1, force: true)
      : _load(state.page + 1, force: false);

  Future<void> _load(int page, {required bool force}) async {
    final generation = page == 1 ? ++_generation : _generation;
    state = PagedState(
      items: page == 1 && !force ? const [] : state.items,
      page: state.page,
      hasMore: state.hasMore,
      isLoading: true,
      stale: state.stale,
    );
    try {
      final result = await _fetch(ref, page, force);
      if (!ref.mounted || generation != _generation) return;
      final existing = page == 1 ? <T>[] : state.items;
      final seen = {for (final i in existing) _idOf(i)};
      state = PagedState(
        items: [...existing, ...result.items.where((i) => seen.add(_idOf(i)))],
        page: page,
        hasMore: result.hasMore && result.items.isNotEmpty,
        stale: result.stale,
      );
    } on Object catch (error) {
      if (!ref.mounted || generation != _generation) return;
      if (state.items.isEmpty) {
        state = PagedState(error: error, hasMore: false);
      } else {
        // Keep what's on screen; a failed refresh just leaves it in place.
        state = PagedState(
          items: state.items,
          page: state.page,
          hasMore: state.hasMore,
          loadMoreError: page > 1 ? error : null,
          stale: state.stale,
        );
      }
    }
  }
}
