import 'dart:io';

import 'package:allbiohub/core/cache/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('abh_cache');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('stores responses for long URLs and reads them after reopening', () async {
    // Story lists ask for many fields, so their URLs pass Hive's 255
    // character key limit.
    final url =
        'https://allbiohub.com/wp-json/wp/v2/posts?page=1&per_page=12'
        '&_embed=author%2Cwp%3Afeaturedmedia%2Cwp%3Aterm&_fields=${'x' * 300}';
    var store = HiveCacheStore(await Hive.openBox<String>('api_cache'));
    await store.write(url, {
      'd': [
        {'id': 1},
      ],
      'p': 3,
    });

    await Hive.close();
    store = HiveCacheStore(await Hive.openBox<String>('api_cache'));
    final entry = store.read(url)!;
    expect(entry.payload['d'], [
      {'id': 1},
    ]);
    expect(entry.payload['p'], 3);
    expect(store.read('$url&page=2'), isNull);
  });
}
