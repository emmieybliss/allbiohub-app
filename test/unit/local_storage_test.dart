import 'package:allbiohub/core/cache/local_store.dart';
import 'package:allbiohub/core/models/user_preferences.dart';
import 'package:allbiohub/core/networking/wordpress_mapper.dart';
import 'package:allbiohub/core/repositories/local_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';

void main() {
  const mapper = WordPressMapper();

  group('BookmarkRepository', () {
    test('saves, lists newest first, and removes', () async {
      final store = MemoryLocalStore();
      final repo = BookmarkRepository(store);
      await repo.save(mapper.article(wpPost(id: 1)));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.save(mapper.article(wpPost(id: 2)));
      expect(repo.all().map((a) => a.id), [2, 1]);
      expect(repo.contains(1), isTrue);
      await repo.remove(1);
      expect(repo.all().map((a) => a.id), [2]);
    });

    test('survives a restart (same store, new repository)', () async {
      final store = MemoryLocalStore();
      await BookmarkRepository(store).save(mapper.article(wpPost(id: 9)));
      final restored = BookmarkRepository(store).all().single;
      expect(restored.title, 'Tems’ Biography: From Lagos to the World');
      expect(restored.image?.variants, isNotEmpty);
    });

    test('drops corrupt entries', () async {
      final store = MemoryLocalStore()..values['5'] = '{not json';
      expect(BookmarkRepository(store).all(), isEmpty);
      expect(store.values, isEmpty);
    });
  });

  group('PreferencesRepository', () {
    test('defaults, then persists changes', () async {
      final store = MemoryLocalStore();
      final repo = PreferencesRepository(store);
      expect(repo.load().themeMode, ThemeMode.system);
      expect(repo.load().onboardingComplete, isFalse);
      await repo.save(
        const UserPreferences(
          themeMode: ThemeMode.dark,
          textSize: ReaderTextSize.large,
          onboardingComplete: true,
          interestSlugs: {'biography'},
          notificationTopics: {NotificationTopic.startups},
        ),
      );
      final loaded = PreferencesRepository(store).load();
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.textSize, ReaderTextSize.large);
      expect(loaded.onboardingComplete, isTrue);
      expect(loaded.interestSlugs, {'biography'});
      expect(loaded.notificationTopics, {NotificationTopic.startups});
    });

    test('recent searches are unique, newest first and capped', () async {
      final repo = PreferencesRepository(MemoryLocalStore());
      for (var i = 0; i < 10; i++) {
        await repo.addRecentSearch('q$i');
      }
      await repo.addRecentSearch('Q3');
      final recent = repo.recentSearches();
      expect(recent.first, 'Q3');
      expect(recent.where((s) => s.toLowerCase() == 'q3'), hasLength(1));
      expect(recent, hasLength(PreferencesRepository.maxRecentSearches));
    });
  });
}
