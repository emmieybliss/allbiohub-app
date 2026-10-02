import 'package:allbiohub/core/models/article.dart';
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
    expect(find.text('List your startup'), findsOneWidget);
    expect(find.text('Claim your startup'), findsOneWidget);
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
