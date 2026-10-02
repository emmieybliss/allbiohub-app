import 'package:hive_ce/hive.dart';

/// Minimal persistent string key/value store used for bookmarks, settings
/// and search history. Hive-backed in the app, in-memory in tests.
abstract class LocalStore {
  String? get(String key);
  Iterable<String> get keys;
  Future<void> put(String key, String value);
  Future<void> delete(String key);
}

class HiveLocalStore implements LocalStore {
  HiveLocalStore(this._box);

  final Box<String> _box;

  @override
  String? get(String key) => _box.get(key);

  @override
  Iterable<String> get keys => _box.keys.map((k) => '$k');

  @override
  Future<void> put(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}

class MemoryLocalStore implements LocalStore {
  final Map<String, String> values = {};

  @override
  String? get(String key) => values[key];

  @override
  Iterable<String> get keys => values.keys;

  @override
  Future<void> put(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
