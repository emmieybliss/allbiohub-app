import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache/cache_store.dart';
import 'community/saved.dart';
import 'cache/local_store.dart';
import 'config/app_config.dart';
import 'models/article.dart';
import 'models/user_preferences.dart';
import 'networking/api_client.dart';
import 'repositories/article_repository.dart';
import 'repositories/local_repositories.dart';
import 'repositories/startup_repository.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

// Dependency graph. Storage providers are overridden in main.dart once Hive
// boxes are open, and in tests with in-memory implementations.

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final appVersionProvider = Provider<String>((ref) => '1.0.0');

final cacheStoreProvider = Provider<CacheStore>((ref) => MemoryCacheStore());
final bookmarkStoreProvider = Provider<LocalStore>((ref) => MemoryLocalStore());
final settingsStoreProvider = Provider<LocalStore>((ref) => MemoryLocalStore());

final dioProvider = Provider<Dio>((ref) {
  final dio = ApiClient.createDio(
    userAgent: 'AllBioHubApp/${ref.watch(appVersionProvider)} (Android)',
  );
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    dio: ref.watch(dioProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);

final articleRepositoryProvider = Provider<ArticleRepository>(
  (ref) => ArticleRepository(
    client: ref.watch(apiClientProvider),
    config: ref.watch(appConfigProvider),
    taxonomy: ref.watch(taxonomyRepositoryProvider),
  ),
);

final taxonomyRepositoryProvider = Provider<TaxonomyRepository>(
  (ref) => TaxonomyRepository(
    client: ref.watch(apiClientProvider),
    config: ref.watch(appConfigProvider),
  ),
);

final startupRepositoryProvider = Provider<StartupRepository>(
  (ref) => StartupRepository(
    client: ref.watch(apiClientProvider),
    config: ref.watch(appConfigProvider),
  ),
);

final bookmarkRepositoryProvider = Provider<BookmarkRepository>(
  (ref) => BookmarkRepository(ref.watch(bookmarkStoreProvider)),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(settingsStoreProvider)),
);

final analyticsProvider = Provider<AnalyticsService>(
  (ref) =>
      kDebugMode ? const DebugAnalyticsService() : const NoopAnalyticsService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => const DisabledNotificationService(),
);

/// Where a tapped notification asked to go while the splash was still up.
/// The splash takes it when it moves on.
class PendingLocationNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String location) => state = location;

  String? take() {
    final location = state;
    state = null;
    return location;
  }
}

final pendingLocationProvider =
    NotifierProvider<PendingLocationNotifier, String?>(
      PendingLocationNotifier.new,
    );

/// Settings, persisted on every change.
class PreferencesNotifier extends Notifier<UserPreferences> {
  @override
  UserPreferences build() => ref.watch(preferencesRepositoryProvider).load();

  Future<void> update(UserPreferences Function(UserPreferences) change) async {
    state = change(state);
    await ref.read(preferencesRepositoryProvider).save(state);
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, UserPreferences>(
      PreferencesNotifier.new,
    );

/// Saved articles, newest first.
class BookmarksNotifier extends Notifier<List<Article>> {
  @override
  List<Article> build() => ref.watch(bookmarkRepositoryProvider).all();

  bool isSaved(int id) => state.any((a) => a.id == id);

  /// Returns true when the article is now saved.
  Future<bool> toggle(Article article) async {
    final repo = ref.read(bookmarkRepositoryProvider);
    final analytics = ref.read(analyticsProvider);
    if (isSaved(article.id)) {
      state = state.where((a) => a.id != article.id).toList();
      await repo.remove(article.id);
      analytics.log(AnalyticsEvent.articleUnsave, {'article_id': article.id});
      _mirror(article, saved: false);
      return false;
    }
    state = [article, ...state];
    await repo.save(article);
    analytics.log(AnalyticsEvent.articleSave, {'article_id': article.id});
    _mirror(article, saved: true);
    return true;
  }

  Future<void> remove(int id) async {
    final article = state.where((a) => a.id == id).firstOrNull;
    state = state.where((a) => a.id != id).toList();
    await ref.read(bookmarkRepositoryProvider).remove(id);
    if (article != null) _mirror(article, saved: false);
  }

  /// Adds a story saved to the account on another phone.
  Future<void> addFromAccount(Article article) async {
    if (isSaved(article.id)) return;
    state = [...state, article];
    await ref.read(bookmarkRepositoryProvider).save(article);
  }

  /// Copies the change to the signed-in account (when sync is on).
  void _mirror(Article article, {required bool saved}) => ref
      .read(savedSyncProvider)
      .mirror(
        kind: 'article',
        id: '${article.id}',
        title: article.title,
        image: article.image?.urlFor(600),
        url: article.link,
        data: saved ? article.toJson() : null,
        saved: saved,
      );
}

final bookmarksProvider = NotifierProvider<BookmarksNotifier, List<Article>>(
  BookmarksNotifier.new,
);

final isBookmarkedProvider = Provider.family<bool, int>(
  (ref, id) => ref.watch(bookmarksProvider).any((a) => a.id == id),
);
