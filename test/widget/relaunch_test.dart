// Closing and reopening the app: the second launch reads back what the
// first one saved (settings, bookmarks and cached responses, which go
// through JSON as they do on the phone).
import 'dart:convert';

import 'package:allbiohub/app.dart';
import 'package:allbiohub/core/cache/cache_store.dart';
import 'package:allbiohub/shared/widgets/article_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/test_app.dart';
import 'journeys_test.dart' show launch, onePage, tapTab;

/// Stores entries as JSON text, like the Hive cache on the phone.
class JsonCacheStore extends MemoryCacheStore {
  @override
  CacheEntry? read(String key) {
    final entry = super.read(key);
    if (entry == null) return null;
    return CacheEntry(
      storedAt: entry.storedAt,
      payload: jsonDecode(jsonEncode(entry.payload)) as Map<String, dynamic>,
    );
  }
}

class RelaunchEnv extends TestEnv {
  RelaunchEnv(super.routes);

  @override
  final cache = JsonCacheStore();
}

void main() {
  testWidgets('the app opens again after being closed', (tester) async {
    final env = RelaunchEnv({
      '/wp-json/wp/v2/posts': FakeResponse([
        wpPost(),
        for (var i = 2; i <= 6; i++)
          wpPost(id: 100 + i, slug: 'story-$i', title: 'Story $i'),
      ], headers: onePage),
      '/wp-json/wp/v2/categories': FakeResponse(wpCategories()),
      '/wp-json/wp/v2/tags': const FakeResponse([]),
    });

    await launch(tester, env);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    for (final tab in ['Discover', 'Startups', 'Saved', 'Profile', 'Home']) {
      await tapTab(tester, tab);
    }
    await tester.tap(find.byType(ArticleHeroCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save story').first);
    await tester.pump(const Duration(seconds: 3));

    // Close the app, then open it again with the same storage.
    await tester.pumpWidget(const SizedBox());
    await launch(tester, env);

    expect(tester.takeException(), isNull);
    expect(find.text('Skip'), findsNothing);
    expect(find.byType(ArticleHeroCard), findsWidgets);
    for (final tab in ['Discover', 'Startups', 'Saved', 'Profile', 'Home']) {
      await tapTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tapTab(tester, 'Saved');
    expect(find.byType(ArticleListTile), findsOneWidget);
  });
}
