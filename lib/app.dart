import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/community/community_providers.dart';
import 'core/community/saved.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';
import 'core/services/analytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';

class AllBioHubApp extends ConsumerStatefulWidget {
  const AllBioHubApp({super.key});

  @override
  ConsumerState<AllBioHubApp> createState() => _AllBioHubAppState();
}

class _AllBioHubAppState extends ConsumerState<AllBioHubApp> {
  StreamSubscription<NotificationTarget>? _taps;

  @override
  void initState() {
    super.initState();
    // Account housekeeping: register this phone for personal notifications
    // and sync saved items while someone is signed in. Both do nothing
    // while accounts are unavailable.
    ref.read(deviceRegistrationProvider);
    ref.read(savedSyncProvider);
    final notifications = ref.read(notificationServiceProvider);
    if (notifications.isAvailable) {
      _taps = notifications.opened.listen(_openNotification);
      unawaited(_startNotifications(notifications));
    }
  }

  Future<void> _startNotifications(NotificationService service) async {
    try {
      await service.initialize();
      await service.syncTopics(
        ref.read(preferencesProvider).notificationTopics,
      );
    } catch (e) {
      debugPrint('Notifications not started: $e');
    }
  }

  /// Opens the page a tapped notification links to (an allbiohub.com URL).
  void _openNotification(NotificationTarget target) {
    if (!mounted) return;
    ref.read(analyticsProvider).log(AnalyticsEvent.notificationOpen, {
      'path': target.url.path,
    });
    final location = target.url.hasScheme
        ? ref.read(deepLinkParserProvider).locationFor(target.url) ??
              Routes.home
        : target.url.toString();
    final router = ref.read(routerProvider);
    final current = router.routerDelegate.currentConfiguration.uri.path;
    if (current == Routes.splash || current == Routes.onboarding) {
      ref.read(pendingLocationProvider.notifier).set(location);
    } else if (_tabRoots.contains(location)) {
      router.go(location);
    } else {
      router.push(location);
    }
  }

  static const _tabRoots = {
    Routes.home,
    Routes.discover,
    Routes.startups,
    Routes.saved,
    Routes.profile,
  };

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(preferencesProvider.select((p) => p.themeMode));
    return MaterialApp.router(
      title: 'AllBioHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Respect the system text size but cap it so layouts stay usable.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
