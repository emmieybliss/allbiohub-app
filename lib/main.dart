import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/cache/cache_store.dart';
import 'core/cache/local_store.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'core/services/analytics_service.dart';
import 'core/services/firebase_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage is opened before the first frame so settings (theme,
  // onboarding) apply immediately. These boxes are small and open quickly.
  await Hive.initFlutter();
  final boxes = await Future.wait([
    Hive.openBox<String>(HiveCacheStore.boxName),
    Hive.openBox<String>('bookmarks'),
    Hive.openBox<String>('settings'),
  ]);
  final info = await PackageInfo.fromPlatform();
  // Notifications and analytics stay off unless the build has Firebase
  // settings (README → Firebase).
  final firebase = await initializeFirebase(AppConfig.fromEnvironment());

  runApp(
    ProviderScope(
      // Screens show their own Retry button; don't retry failed requests
      // automatically in the background.
      retry: (_, _) => null,
      overrides: [
        cacheStoreProvider.overrideWithValue(HiveCacheStore(boxes[0])),
        bookmarkStoreProvider.overrideWithValue(HiveLocalStore(boxes[1])),
        settingsStoreProvider.overrideWithValue(HiveLocalStore(boxes[2])),
        appVersionProvider.overrideWithValue(info.version),
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
        ],
      ],
      child: const AllBioHubApp(),
    ),
  );
}
