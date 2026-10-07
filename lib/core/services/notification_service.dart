import 'dart:async';

import '../models/user_preferences.dart';

/// What a notification asks the app to open, parsed from its data payload
/// (`url` with an allbiohub.com link).
class NotificationTarget {
  const NotificationTarget(this.url);

  final Uri url;
}

/// Push notifications. Topic subscriptions mirror the person's choices in
/// Profile → Notifications.
///
/// [DisabledNotificationService] is used until Firebase is configured (see
/// README "Firebase"). A Firebase Cloud Messaging implementation plugs in
/// here without changes to the screens.
abstract class NotificationService {
  /// Whether push is configured in this build.
  bool get isAvailable;

  Future<void> initialize();

  /// Asks the OS for permission (Android 13+). Returns whether granted.
  Future<bool> requestPermission();

  Future<void> syncTopics(Set<NotificationTopic> topics);

  /// Notifications the person tapped.
  Stream<NotificationTarget> get opened;

  /// This device's push token, so personal notifications (replies, followed
  /// startups) can reach it. Null when push isn't available.
  Future<String?> token();

  Stream<String> get tokenRefreshes;
}

class DisabledNotificationService implements NotificationService {
  const DisabledNotificationService();

  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> syncTopics(Set<NotificationTopic> topics) async {}

  @override
  Stream<NotificationTarget> get opened => const Stream.empty();

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}
