import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/cache/cache_store.dart';
import 'core/cache/local_store.dart';
import 'core/community/community_providers.dart';
import 'core/community/firebase_community.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'core/services/analytics_service.dart';
import 'core/services/firebase_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage is opened before the first frame so settings (theme,
  // onboarding) apply immediately. Nothing here may stop the app from
  // opening: each step has a fallback.
  final stores = await _openStores();
  final version = await PackageInfo.fromPlatform()
      .then((info) => info.version)
      .timeout(const Duration(seconds: 3))
      .catchError((Object _) => '');
  // Notifications and analytics stay off unless the build has Firebase
  // settings (README → Firebase), or if Firebase doesn't answer in time.
  final config = AppConfig.fromEnvironment();
  final firebase = await initializeFirebase(config)
      .timeout(const Duration(seconds: 5), onTimeout: () => false);

  runApp(
    ProviderScope(
      // Screens show their own Retry button; don't retry failed requests
      // automatically in the background.
      retry: (_, _) => null,
      overrides: [
        cacheStoreProvider.overrideWithValue(stores.cache),
        bookmarkStoreProvider.overrideWithValue(stores.bookmarks),
        settingsStoreProvider.overrideWithValue(stores.settings),
        savedEntityStoreProvider.overrideWithValue(stores.savedEntities),
        appVersionProvider.overrideWithValue(version),
        if (firebase) ...[
          notificationServiceProvider.overrideWithValue(
            FirebaseNotificationService(),
          ),
          analyticsProvider.overrideWithValue(
            CompositeAnalyticsService([
              FirebaseAnalyticsService(),
              const DebugAnalyticsService(),
            ]),
          ),
          // Community features (COMMUNITY.md). Each stays hidden until it
          // is switched on in the config/app document.
          authRepositoryProvider.overrideWithValue(
            FirebaseAuthRepository(
              googleServerClientId: config.googleWebClientId,
            ),
          ),
          communityApiProvider.overrideWithValue(
            FirebaseCommunityApi(functionsRegion: config.functionsRegion),
          ),
          featureFlagSourceProvider.overrideWithValue(
            FirestoreFeatureFlagSource(),
          ),
        ],
      ],
      child: const AllBioHubApp(),
    ),
  );
}

/// On-device storage. If a box can't be opened (a damaged file, a full
/// disk), the app still opens: a damaged cache is rebuilt, and settings or
/// bookmarks fall back to memory for this session without being deleted.
Future<
  ({
    CacheStore cache,
    LocalStore bookmarks,
    LocalStore settings,
    LocalStore savedEntities,
  })
>
_openStores() async {
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('Storage unavailable, using memory: $e');
    return (
      cache: MemoryCacheStore(),
      bookmarks: MemoryLocalStore(),
      settings: MemoryLocalStore(),
      savedEntities: MemoryLocalStore(),
    );
  }

  Future<Box<String>?> open(String name, {bool rebuild = false}) async {
    try {
      return await Hive.openBox<String>(name)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Could not open $name: $e');
      if (!rebuild) return null;
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<String>(name);
      } catch (_) {
        return null;
      }
    }
  }

  final boxes = await Future.wait([
    open(HiveCacheStore.boxName, rebuild: true),
    open('bookmarks'),
    open('settings'),
    open('saved_entities'),
  ]);
  return (
    cache: boxes[0] == null
        ? MemoryCacheStore()
        : HiveCacheStore(boxes[0]!) as CacheStore,
    bookmarks: boxes[1] == null
        ? MemoryLocalStore()
        : HiveLocalStore(boxes[1]!) as LocalStore,
    settings: boxes[2] == null
        ? MemoryLocalStore()
        : HiveLocalStore(boxes[2]!) as LocalStore,
    savedEntities: boxes[3] == null
        ? MemoryLocalStore()
        : HiveLocalStore(boxes[3]!) as LocalStore,
  );
}
