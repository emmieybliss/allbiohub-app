import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';

/// A cached JSON payload and when it was stored.
class CacheEntry {
  const CacheEntry({required this.storedAt, required this.payload});

  final DateTime storedAt;
  final Map<String, dynamic> payload;

  bool isFresh(Duration maxAge, DateTime now) =>
      now.difference(storedAt) < maxAge;
}

/// Key/value store for API responses. Backed by Hive in the app and by an
/// in-memory map in tests.
abstract class CacheStore {
  CacheEntry? read(String key);
  Future<void> write(String key, Map<String, dynamic> payload);
  Future<void> clear();
}

class HiveCacheStore implements CacheStore {
  HiveCacheStore(this._box, {this.maxEntries = 400});

  static const boxName = 'api_cache';

  final Box<String> _box;

  /// Oldest entries are dropped past this size so the cache can't grow forever.
  final int maxEntries;

  /// Hive keys are limited to 255 characters and request URLs are often
  /// longer, so entries are stored under a hash of the URL.
  static String boxKey(String key) => sha1.convert(utf8.encode(key)).toString();

  @override
  CacheEntry? read(String key) {
    final raw = _box.get(boxKey(key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CacheEntry(
        storedAt: DateTime.fromMillisecondsSinceEpoch(decoded['t'] as int),
        payload: decoded['p'] as Map<String, dynamic>,
      );
    } catch (_) {
      _box.delete(boxKey(key));
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> payload) async {
    await _box.put(
      boxKey(key),
      jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'p': payload}),
    );
    if (_box.length > maxEntries) {
      await _box.deleteAll(_box.keys.take(_box.length - maxEntries).toList());
    }
  }

  @override
  Future<void> clear() => _box.clear();
}

class MemoryCacheStore implements CacheStore {
  final Map<String, CacheEntry> entries = {};

  @override
  CacheEntry? read(String key) => entries[key];

  @override
  Future<void> write(String key, Map<String, dynamic> payload) async {
    entries[key] = CacheEntry(storedAt: DateTime.now(), payload: payload);
  }

  @override
  Future<void> clear() async => entries.clear();
}
