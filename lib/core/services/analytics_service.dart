import 'package:flutter/foundation.dart';

/// Product events the app records. Names follow Firebase Analytics rules
/// (snake_case, ≤40 chars) so they can be forwarded unchanged.
enum AnalyticsEvent {
  appOpen('app_open'),
  articleView('article_view'),
  articleShare('article_share'),
  articleSave('article_save'),
  articleUnsave('article_unsave'),
  startupView('startup_view'),
  startupSearch('startup_search'),
  startupShare('startup_share'),
  categoryView('category_view'),
  search('search'),
  notificationOpen('notification_open');

  const AnalyticsEvent(this.name);

  final String name;
}

/// Analytics sink. Screens call [log] with content identifiers only (ids,
/// slugs, categories). Never pass personal data: no names, emails or
/// device identifiers.
///
/// Implementations: [DebugAnalyticsService] (prints in debug builds) and
/// [NoopAnalyticsService]. A Firebase Analytics sink and a sink for the
/// website's own `ab-analytics` system can be added side by side with
/// [CompositeAnalyticsService] without touching any screen.
abstract class AnalyticsService {
  Future<void> log(
    AnalyticsEvent event, [
    Map<String, Object> params = const {},
  ]);
  Future<void> screen(String name);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> log(
    AnalyticsEvent event, [
    Map<String, Object> params = const {},
  ]) async {}

  @override
  Future<void> screen(String name) async {}
}

class DebugAnalyticsService implements AnalyticsService {
  const DebugAnalyticsService();

  @override
  Future<void> log(
    AnalyticsEvent event, [
    Map<String, Object> params = const {},
  ]) async {
    if (kDebugMode) debugPrint('[analytics] ${event.name} $params');
  }

  @override
  Future<void> screen(String name) async {
    if (kDebugMode) debugPrint('[analytics] screen $name');
  }
}

class CompositeAnalyticsService implements AnalyticsService {
  const CompositeAnalyticsService(this.sinks);

  final List<AnalyticsService> sinks;

  @override
  Future<void> log(
    AnalyticsEvent event, [
    Map<String, Object> params = const {},
  ]) async {
    for (final sink in sinks) {
      try {
        await sink.log(event, params);
      } on Object {
        // Analytics must never break the app.
      }
    }
  }

  @override
  Future<void> screen(String name) async {
    for (final sink in sinks) {
      try {
        await sink.screen(name);
      } on Object {
        // Analytics must never break the app.
      }
    }
  }
}
