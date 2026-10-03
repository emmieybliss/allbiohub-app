import 'dart:convert';
import 'dart:io';

import 'package:allbiohub/core/models/article.dart';
import 'package:allbiohub/core/models/startup.dart';
import 'package:allbiohub/core/networking/wordpress_mapper.dart';
import 'package:allbiohub/core/providers.dart';
import 'package:allbiohub/features/articles/article_screen.dart';
import 'package:allbiohub/features/bookmarks/saved_screen.dart';
import 'package:allbiohub/features/home/home_screen.dart';
import 'package:allbiohub/features/startups/startups_home_screen.dart';
import 'package:allbiohub/shared/widgets/article_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/test_app.dart';

const onePage = {'x-wp-totalpages': '1'};

void main() {
  final article = const WordPressMapper().article(wpPost());

  testWidgets('Saved shows a helpful empty state', (tester) async {
    await pumpScreen(tester, const SavedScreen(), env: TestEnv());
    expect(find.text('Nothing saved yet.'), findsOneWidget);
    expect(find.text('Save stories you want to read later.'), findsOneWidget);
  });

  testWidgets('Saved lists bookmarks from storage', (tester) async {
    final env = TestEnv();
    final container = await pumpScreen(tester, const SavedScreen(), env: env);
    await container.read(bookmarksProvider.notifier).toggle(article);
    await tester.pump();
    expect(find.byType(ArticleListTile), findsOneWidget);
    expect(env.bookmarks.values, hasLength(1));
  });

  testWidgets('Home shows the featured story and latest list', (tester) async {
    final env = TestEnv({
      '/wp-json/wp/v2/posts': FakeResponse(
        [
          for (var i = 1; i <= 8; i++)
            wpPost(id: i, slug: 's$i', title: 'Story $i'),
        ],
        headers: const {'x-wp-totalpages': '1'},
      ),
      '/wp-json/wp/v2/categories': const FakeResponse([]),
    });
    await pumpScreen(tester, const HomeScreen(), env: env);
    await tester.pumpAndSettle();
    expect(find.byType(ArticleHeroCard), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Story 4'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Latest stories'), findsOneWidget);
    expect(find.text('Story 4'), findsOneWidget);
  });

  testWidgets('Home explains an offline failure with Retry, not raw errors', (
    tester,
  ) async {
    final env = TestEnv()..adapter.offline = true;
    await pumpScreen(tester, const HomeScreen(), env: env);
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);

    env.adapter
      ..offline = false
      ..routes['/wp-json/wp/v2/posts'] = FakeResponse([
        wpPost(title: 'Back online'),
      ], headers: onePage);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Back online'), findsWidgets);
  });

  testWidgets('Home falls back to cached stories when offline', (tester) async {
    final env = TestEnv({
      '/wp-json/wp/v2/posts': FakeResponse([
        wpPost(title: 'Cached story'),
      ], headers: onePage),
      '/wp-json/wp/v2/categories': const FakeResponse([]),
    });
    await pumpScreen(tester, const HomeScreen(), env: env);
    await tester.pumpAndSettle();
    env.adapter.offline = true;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Cached story'), findsWidgets);
    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('Article reader shows content and saves the story', (
    tester,
  ) async {
    final env = TestEnv({'/wp-json/wp/v2/posts/101': FakeResponse(wpPost())});
    final container = await pumpScreen(
      tester,
      ArticleScreen(id: 101, preview: article),
      env: env,
    );
    await tester.pumpAndSettle();
    expect(find.text(article.title), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Ada Obi'), findsOneWidget);
    expect(
      find.textContaining('was born in Lagos', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Save story').first);
    await tester.pump();
    expect(container.read(bookmarksProvider).map((Article a) => a.id), [101]);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Startups tab explains when the directory API is missing', (
    tester,
  ) async {
    await pumpScreen(tester, const StartupsHomeScreen(), env: TestEnv());
    await tester.pumpAndSettle();
    expect(find.text('The startup directory is on its way'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Get Verified →'), 200);
    expect(find.text('List Your Startup'), findsOneWidget);
    expect(find.text('Claim Your Startup'), findsOneWidget);
  });

  group('Startups tab follows the website layout', () {
    final sample = jsonDecode(
      File('test/fixtures/startup_api_sample.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    TestEnv startupEnv(List<dynamic> list, {String total = '208'}) => TestEnv({
      '/wp-json/allbiohub/v1/startups': FakeResponse(
        list,
        headers: {'x-wp-total': total, 'x-wp-totalpages': '21'},
      ),
      '/wp-json/allbiohub/v1/startups/filters': FakeResponse(sample['filters']),
    });

    testWidgets('hero, stats, featured, browse, list and call to action', (
      tester,
    ) async {
      final env = startupEnv(sample['list'] as List<dynamic>);
      await pumpScreen(tester, const StartupsHomeScreen(), env: env);
      await tester.pumpAndSettle();

      expect(find.text('Discover African Startups'), findsOneWidget);
      expect(find.text('Claim Your Profile'), findsOneWidget);
      expect(find.text('208'), findsWidgets);
      expect(find.text('Featured startups'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      for (final text in [
        'Browse by industry',
        'All startups',
        'See all 208 startups',
        'Browse by country',
        'Building something in Africa?',
        'Get Verified →',
      ]) {
        await tester.scrollUntilVisible(
          find.text(text),
          200,
          scrollable: scrollable,
        );
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('sorting uses the website options', (tester) async {
      final env = startupEnv(sample['list'] as List<dynamic>);
      await pumpScreen(tester, const StartupsHomeScreen(), env: env);
      await tester.pumpAndSettle();
      final sort = find.byType(DropdownButtonFormField<StartupSort>);
      await tester.scrollUntilVisible(
        sort,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(sort);
      await tester.pumpAndSettle();
      for (final label in ['Founded recently', 'Oldest', 'Alphabetical']) {
        expect(find.text(label), findsWidgets);
      }
      await tester.tap(find.text('Featured first').last);
      await tester.pumpAndSettle();
      expect(
        env.adapter.requests.map((r) => r.uri.queryParameters['orderby']),
        contains('featured'),
      );
    });

    testWidgets('an empty directory says so instead of looking broken', (
      tester,
    ) async {
      final env = startupEnv(const [], total: '0');
      await pumpScreen(tester, const StartupsHomeScreen(), env: env);
      await tester.pumpAndSettle();
      expect(find.text('Featured startups'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('No startups to show yet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Browse startups on allbiohub.com'), findsOneWidget);
    });
  });

  testWidgets('screens render in dark mode', (tester) async {
    final env = TestEnv({
      '/wp-json/wp/v2/posts': FakeResponse([wpPost()], headers: onePage),
      '/wp-json/wp/v2/categories': const FakeResponse([]),
    });
    await pumpScreen(
      tester,
      const HomeScreen(),
      env: env,
      themeMode: ThemeMode.dark,
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
