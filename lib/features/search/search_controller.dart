import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/models/search_result.dart';
import '../../core/models/startup.dart';
import '../../core/networking/app_exception.dart';
import '../../core/providers.dart';
import '../../core/repositories/startup_repository.dart';
import '../../core/services/analytics_service.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.results,
    this.isLoading = false,
    this.error,
    this.recent = const [],
  });

  final String query;
  final SearchResults? results;
  final bool isLoading;
  final Object? error;
  final List<String> recent;

  SearchState copyWith({
    String? query,
    SearchResults? Function()? results,
    bool? isLoading,
    Object? Function()? error,
    List<String>? recent,
  }) => SearchState(
    query: query ?? this.query,
    results: results == null ? this.results : results(),
    isLoading: isLoading ?? this.isLoading,
    error: error == null ? this.error : error(),
    recent: recent ?? this.recent,
  );
}

/// Global search across stories, startups and topics. Typing is debounced,
/// and an in-flight search is cancelled when the query changes.
class GlobalSearchController extends Notifier<SearchState> {
  static const debounce = Duration(milliseconds: 450);
  static const minLength = 2;

  Timer? _timer;
  CancelToken? _cancel;

  @override
  SearchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _cancel?.cancel();
    });
    return SearchState(
      recent: ref.read(preferencesRepositoryProvider).recentSearches(),
    );
  }

  void onQueryChanged(String value) {
    final query = value.trim();
    _timer?.cancel();
    if (query == state.query) return;
    if (query.length < minLength) {
      _cancel?.cancel();
      state = state.copyWith(
        query: query,
        results: () => null,
        isLoading: false,
        error: () => null,
      );
      return;
    }
    state = state.copyWith(query: query, isLoading: true, error: () => null);
    _timer = Timer(debounce, () => _run(query));
  }

  /// Search now (keyboard search button or a recent search tap).
  Future<void> submit(String value) async {
    final query = value.trim();
    _timer?.cancel();
    if (query.length < minLength) return;
    final recent = await ref
        .read(preferencesRepositoryProvider)
        .addRecentSearch(query);
    state = state.copyWith(query: query, recent: recent);
    if (state.results?.query != query) await _run(query);
  }

  void retry() => _run(state.query);

  Future<void> clearRecent() async {
    await ref.read(preferencesRepositoryProvider).clearRecentSearches();
    state = state.copyWith(recent: const []);
  }

  Future<void> _run(String query) async {
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    state = state.copyWith(isLoading: true, error: () => null);

    final articlesFuture = ref
        .read(articleRepositoryProvider)
        .search(query, cancelToken: cancel);
    final topicsFuture = ref
        .read(taxonomyRepositoryProvider)
        .searchTopics(query, cancelToken: cancel)
        .catchError((Object _) => <Category>[]);
    var startupsAvailable = true;
    final startupsFuture = ref
        .read(startupRepositoryProvider)
        .list(StartupQuery(search: query), perPage: 10, cancelToken: cancel)
        .then((p) => p.items)
        .catchError((Object e) {
          startupsAvailable = e is! StartupDirectoryUnavailable;
          return <Startup>[];
        });

    try {
      final articles = await articlesFuture;
      final topics = await topicsFuture;
      final startups = await startupsFuture;
      if (!ref.mounted || cancel.isCancelled || state.query != query) return;
      state = state.copyWith(
        isLoading: false,
        results: () => SearchResults(
          query: query,
          articles: articles.items,
          topics: topics,
          startups: startups,
          startupsAvailable: startupsAvailable,
        ),
      );
      final analytics = ref.read(analyticsProvider);
      analytics.log(AnalyticsEvent.search, {
        'search_term': query,
        'results': articles.items.length,
      });
      if (startups.isNotEmpty) {
        analytics.log(AnalyticsEvent.startupSearch, {'search_term': query});
      }
    } on Object catch (error) {
      if (!ref.mounted || cancel.isCancelled || state.query != query) return;
      if (AppException.from(error).kind == AppErrorKind.cancelled) return;
      state = state.copyWith(isLoading: false, error: () => error);
    }
  }
}

final searchControllerProvider =
    NotifierProvider.autoDispose<GlobalSearchController, SearchState>(
      GlobalSearchController.new,
    );
