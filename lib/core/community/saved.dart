import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/local_store.dart';
import '../models/article.dart';
import '../models/startup.dart';
import '../providers.dart';
import '../services/analytics_service.dart';
import 'community_providers.dart';
import 'feature_flags.dart';
import 'models.dart';

/// Saved startups and founders, kept on this device like saved stories.
class SavedEntitiesNotifier extends Notifier<List<SavedEntity>> {
  LocalStore get _store => ref.read(savedEntityStoreProvider);

  @override
  List<SavedEntity> build() {
    final store = ref.watch(savedEntityStoreProvider);
    final items = <SavedEntity>[];
    for (final key in store.keys.toList()) {
      final raw = store.get(key);
      if (raw == null) continue;
      try {
        items.add(
          SavedEntity.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } on Object {
        // Skip a damaged entry.
      }
    }
    items.sort(
      (a, b) => (b.savedAt ?? DateTime(0)).compareTo(a.savedAt ?? DateTime(0)),
    );
    return items;
  }

  bool isSaved(SavedKind kind, String id) =>
      state.any((e) => e.kind == kind && e.id == id);

  /// Returns true when the item is now saved.
  Future<bool> toggle(SavedEntity entity) async {
    final saved = isSaved(entity.kind, entity.id);
    if (saved) {
      state = state.where((e) => e.key != entity.key).toList();
      await _store.delete(entity.key);
    } else {
      final item = SavedEntity(
        kind: entity.kind,
        id: entity.id,
        title: entity.title,
        subtitle: entity.subtitle,
        image: entity.image,
        url: entity.url,
        savedAt: DateTime.now(),
      );
      state = [item, ...state];
      await _store.put(item.key, jsonEncode(item.toJson()));
      unawaited(
        ref.read(analyticsProvider).log(
          entity.kind == SavedKind.startup
              ? AnalyticsEvent.startupSave
              : AnalyticsEvent.founderSave,
          {'slug': entity.id},
        ),
      );
    }
    unawaited(
      ref
          .read(savedSyncProvider)
          .mirror(
            kind: entity.kind.name,
            id: entity.id,
            title: entity.title,
            image: entity.image,
            url: entity.url,
            saved: !saved,
          ),
    );
    return !saved;
  }

  /// Adds an item that came from the account on another phone.
  Future<void> addFromAccount(SavedEntity entity) async {
    if (isSaved(entity.kind, entity.id)) return;
    state = [...state, entity];
    await _store.put(entity.key, jsonEncode(entity.toJson()));
  }
}

final savedEntitiesProvider =
    NotifierProvider<SavedEntitiesNotifier, List<SavedEntity>>(
      SavedEntitiesNotifier.new,
    );

final isEntitySavedProvider = Provider.family<bool, (SavedKind, String)>(
  (ref, key) => ref
      .watch(savedEntitiesProvider)
      .any((e) => e.kind == key.$1 && e.id == key.$2),
);

SavedEntity savedStartup(Startup s) => SavedEntity(
  kind: SavedKind.startup,
  id: s.slug,
  title: s.name,
  subtitle: [s.industry, s.country].whereType<String>().join(' · '),
  image: s.logo?.urlFor(200),
  url: s.link,
);

/// Copies saved items to the signed-in account and back, when the
/// "savedSync" switch is on. Saving always works on the phone first; a
/// change that can't reach the server is retried later instead of being
/// reported as synced.
class SavedSync {
  SavedSync(this._ref);

  final Ref _ref;
  static const _pendingKey = 'saved_sync_pending';
  bool _running = false;

  bool get _enabled =>
      _ref.read(currentUidProvider) != null &&
      _ref.read(featureProvider(Feature.savedSync));

  LocalStore get _settings => _ref.read(settingsStoreProvider);

  List<Map<String, dynamic>> _pending() {
    try {
      return [
        for (final e in jsonDecode(_settings.get(_pendingKey) ?? '[]') as List)
          Map<String, dynamic>.from(e as Map),
      ];
    } on Object {
      return [];
    }
  }

  Future<void> _savePending(List<Map<String, dynamic>> items) =>
      _settings.put(_pendingKey, jsonEncode(items));

  /// Sends one change; queues it when offline.
  Future<void> mirror({
    required String kind,
    required String id,
    required String title,
    String? image,
    String? url,
    Object? data,
    required bool saved,
  }) async {
    if (!_enabled) return;
    final change = {
      'kind': kind,
      'id': id,
      'title': title,
      'image': image,
      'url': url,
      'data': data,
      'saved': saved,
    };
    try {
      await _ref
          .read(communityApiProvider)
          .setSaved(
            kind: kind,
            id: id,
            title: title,
            image: image,
            url: url,
            data: data,
            saved: saved,
          );
    } on Object catch (e) {
      debugPrint('Saved item queued for sync: $e');
      final pending = _pending()
        ..removeWhere((p) => p['kind'] == kind && p['id'] == id)
        ..add(change);
      await _savePending(pending);
    }
  }

  /// After signing in: sends what this phone saved, brings in what the
  /// account has, and retries queued changes.
  Future<void> syncNow() async {
    if (!_enabled || _running) return;
    _running = true;
    final api = _ref.read(communityApiProvider);
    final uid = _ref.read(currentUidProvider)!;
    try {
      final importedKey = 'saved_imported_$uid';
      if (_settings.get(importedKey) == null) {
        final articles = _ref.read(bookmarksProvider);
        final entities = _ref.read(savedEntitiesProvider);
        await api.importSaved([
          for (final a in articles)
            {
              'kind': 'article',
              'id': '${a.id}',
              'title': a.title,
              'image': a.image?.urlFor(600),
              'url': a.link,
              'data': a.toJson(),
            },
          for (final e in entities)
            {
              'kind': e.kind.name,
              'id': e.id,
              'title': e.title,
              'image': e.image,
              'url': e.url,
            },
        ]);
        await _settings.put(importedKey, '1');
      }
      for (final change in _pending()) {
        await api.setSaved(
          kind: '${change['kind']}',
          id: '${change['id']}',
          title: '${change['title']}',
          image: change['image'] as String?,
          url: change['url'] as String?,
          data: change['data'],
          saved: change['saved'] == true,
        );
      }
      await _savePending([]);
      final remote = await api.savedItems(uid);
      final bookmarks = _ref.read(bookmarksProvider.notifier);
      final entities = _ref.read(savedEntitiesProvider.notifier);
      for (final item in remote) {
        final kind = item['kind'];
        if (kind == 'article') {
          final data = item['data'];
          if (data is! String) continue;
          try {
            final article = Article.fromJson(
              jsonDecode(data) as Map<String, dynamic>,
            );
            if (!bookmarks.isSaved(article.id)) {
              await bookmarks.addFromAccount(article);
            }
          } on Object {
            // A copy that no longer parses is skipped.
          }
        } else if (kind == 'startup' || kind == 'founder') {
          await entities.addFromAccount(
            SavedEntity(
              kind: kind == 'founder' ? SavedKind.founder : SavedKind.startup,
              id: '${item['id']}',
              title: '${item['title']}',
              image: item['image'] as String?,
              url: item['url'] as String?,
              savedAt: item['savedAt'] as DateTime?,
            ),
          );
        }
      }
    } on Object catch (e) {
      debugPrint('Saved items not synced: $e');
    } finally {
      _running = false;
    }
  }
}

final savedSyncProvider = Provider<SavedSync>((ref) {
  final sync = SavedSync(ref);
  ref.listen(currentUidProvider, (_, uid) {
    if (uid != null) unawaited(sync.syncNow());
  }, fireImmediately: true);
  return sync;
});
