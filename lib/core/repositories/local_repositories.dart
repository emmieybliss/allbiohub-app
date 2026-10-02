import 'dart:convert';

import '../cache/local_store.dart';
import '../models/article.dart';
import '../models/user_preferences.dart';

/// Saved articles, stored on the device. Stored as article summaries so the
/// Saved tab works offline. The interface is deliberately small so a cloud
/// sync implementation can replace it once accounts exist.
class BookmarkRepository {
  BookmarkRepository(this._store);

  final LocalStore _store;

  /// Newest first.
  List<Article> all() {
    final entries = <({DateTime savedAt, Article article})>[];
    for (final key in _store.keys.toList()) {
      final raw = _store.get(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        entries.add((
          savedAt: DateTime.parse(json['savedAt'] as String),
          article: Article.fromJson(json['article'] as Map<String, dynamic>),
        ));
      } on Object {
        _store.delete(key);
      }
    }
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return [for (final e in entries) e.article];
  }

  bool contains(int articleId) => _store.get('$articleId') != null;

  Future<void> save(Article article) => _store.put(
    '${article.id}',
    jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'article': article.toJson(),
    }),
  );

  Future<void> remove(int articleId) => _store.delete('$articleId');
}

class PreferencesRepository {
  PreferencesRepository(this._store);

  final LocalStore _store;

  static const _prefsKey = 'preferences';
  static const _searchesKey = 'recent_searches';
  static const maxRecentSearches = 8;

  UserPreferences load() {
    final raw = _store.get(_prefsKey);
    if (raw == null) return const UserPreferences();
    try {
      return UserPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const UserPreferences();
    }
  }

  Future<void> save(UserPreferences prefs) =>
      _store.put(_prefsKey, jsonEncode(prefs.toJson()));

  List<String> recentSearches() {
    final raw = _store.get(_searchesKey);
    if (raw == null) return const [];
    try {
      return [for (final s in jsonDecode(raw) as List<dynamic>) '$s'];
    } on Object {
      return const [];
    }
  }

  Future<List<String>> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return recentSearches();
    final updated = [
      q,
      ...recentSearches().where((s) => s.toLowerCase() != q.toLowerCase()),
    ].take(maxRecentSearches).toList();
    await _store.put(_searchesKey, jsonEncode(updated));
    return updated;
  }

  Future<void> clearRecentSearches() => _store.delete(_searchesKey);
}
