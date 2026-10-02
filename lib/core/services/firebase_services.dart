import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/user_preferences.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

/// Connects Firebase when the build has its settings (`FIREBASE_*` in the env
/// file; README → Firebase). Returns false, and the app keeps notifications
/// and analytics off, when they are missing or Firebase fails to start.
Future<bool> initializeFirebase(AppConfig config) async {
  if (!config.hasFirebase) return false;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.firebaseApiKey,
        appId: config.firebaseAppId,
        messagingSenderId: config.firebaseMessagingSenderId,
        projectId: config.firebaseProjectId,
      ),
    );
    return true;
  } catch (e) {
    debugPrint('Firebase failed to start, continuing without it: $e');
    return false;
  }
}

/// Push notifications through Firebase Cloud Messaging topics.
///
/// Notifications sent to a topic with `data.url` set to an allbiohub.com
/// link open that page in the app when tapped.
class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  final _opened = StreamController<NotificationTarget>.broadcast();
  Set<NotificationTopic> _subscribed = {};
  bool _started = false;
  bool _synced = false;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    FirebaseMessaging.onMessageOpenedApp.listen(_emit);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _emit(initial);
  }

  void _emit(RemoteMessage message) {
    final url = Uri.tryParse('${message.data['url'] ?? ''}');
    if (url != null && url.hasScheme) _opened.add(NotificationTarget(url));
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Subscribes to the chosen topics and leaves the others. Every topic is
  /// sent once per launch, since subscriptions may have been lost (for
  /// example after the app's data was cleared).
  @override
  Future<void> syncTopics(Set<NotificationTopic> topics) async {
    try {
      for (final topic in NotificationTopic.values) {
        final want = topics.contains(topic);
        if (_synced && want == _subscribed.contains(topic)) continue;
        if (want) {
          await _messaging.subscribeToTopic(topic.topic);
        } else {
          await _messaging.unsubscribeFromTopic(topic.topic);
        }
      }
      _subscribed = {...topics};
      _synced = true;
    } catch (e) {
      // Offline or Play services missing: retried on the next change or launch.
      debugPrint('Notification topics not synced: $e');
    }
  }

  @override
  Stream<NotificationTarget> get opened => _opened.stream;
}

/// Firebase Analytics with only the app's own content events (ids, slugs,
/// categories). Advertising ids are switched off in AndroidManifest.xml.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics])
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> log(
    AnalyticsEvent event, [
    Map<String, Object> params = const {},
  ]) => _analytics.logEvent(
    name: event.name,
    parameters: {
      // Firebase accepts only strings and numbers, with values ≤ 100 chars.
      for (final e in params.entries)
        e.key: switch (e.value) {
          final num n => n,
          final v => '$v'.length > 100 ? '$v'.substring(0, 100) : '$v',
        },
    },
  );

  @override
  Future<void> screen(String name) =>
      _analytics.logScreenView(screenName: name);
}
