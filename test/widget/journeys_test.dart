// End-to-end user journeys through the real app: router, tabs, splash and
// onboarding, with a fake network and in-memory storage.
import 'package:allbiohub/app.dart';
import 'package:allbiohub/core/providers.dart';
import 'package:allbiohub/core/models/user_preferences.dart';
import 'package:allbiohub/core/routing/app_router.dart';
import 'package:allbiohub/core/services/notification_service.dart';
import 'package:allbiohub/features/articles/article_screen.dart';
import 'package:allbiohub/shared/widgets/app_image.dart';
import 'package:allbiohub/shared/widgets/article_cards.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/wp_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/test_app.dart';

const onePage = {'x-wp-totalpages': '1'};

TestEnv siteEnv() => TestEnv({
  '/wp-json/wp/v2/posts': FakeResponse([
    wpPost(),
    for (var i = 2; i <= 6; i++)
      wpPost(id: 100 + i, slug: 'story-$i', title: 'Story $i'),
  ], headers: onePage),
  '/wp-json/wp/v2/posts/101': FakeResponse(wpPost()),
  '/wp-json/wp/v2/categories': FakeResponse(wpCategories()),
  '/wp-json/wp/v2/tags': const FakeResponse([]),
});

/// Launches the whole app and waits for the splash to hand over.
Future<ProviderContainer> launch(
  WidgetTester tester,
  TestEnv env, {
  NotificationService? notifications,
  bool settle = true,
}) async {
  AppImage.disableNetwork = true;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...env.overrides(),
        if (notifications != null)
          notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const AllBioHubApp(),
    ),
  );
  if (settle) {
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
  }
  return ProviderScope.containerOf(tester.element(find.byType(AllBioHubApp)));
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Push notifications that the test taps.
class FakeNotifications implements NotificationService {
  final taps = StreamController<NotificationTarget>.broadcast();
  final synced = <Set<NotificationTopic>>[];
  var started = false;

  @override
  bool get isAvailable => true;

  @override
  Future<void> initialize() async => started = true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> syncTopics(Set<NotificationTopic> topics) async =>
      synced.add({...topics});

  @override
  Stream<NotificationTarget> get opened => taps.stream;

  void tap(String url) => taps.add(NotificationTarget(Uri.parse(url)));
}

Future<void> finishOnboarding(ProviderContainer container) => container
    .read(preferencesProvider.notifier)
    .update((p) => p.copyWith(onboardingComplete: true));

void main() {
  testWidgets('first launch: onboarding, read a story, save it, find it in '
      'Saved', (tester) async {
    final env = siteEnv();
    final container = await launch(tester, env);

    // Onboarding shows once; skipping lands on Home.
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(ArticleHeroCard), findsWidgets);

    // Open the lead story in the native reader.
    await tester.tap(find.byType(ArticleHeroCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(ArticleScreen), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('was born in Lagos', findRichText: true),
      findsOneWidget,
    );

    // Save it, go back, and find it under Saved.
    await tester.tap(find.byTooltip('Save story').first);
    await tester.pump(const Duration(seconds: 3));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapTab(tester, 'Saved');
    expect(find.byType(ArticleListTile), findsOneWidget);
    expect(find.textContaining('Tems'), findsWidgets);

    // Onboarding is remembered.
    expect(container.read(preferencesProvider).onboardingComplete, isTrue);
  });

  testWidgets('allbiohub.com story links open the reader', (tester) async {
    final env = siteEnv();
    final container = await launch(tester, env);
    container.read(routerProvider).go('/tems-biography/');
    await tester.pumpAndSettle();
    expect(find.byType(ArticleScreen), findsOneWidget);
    expect(
      env.adapter.requests.any(
        (r) => r.uri.queryParameters['slug'] == 'tems-biography',
      ),
      isTrue,
    );
  });

  testWidgets('every tab opens, and Startups is honest without its API', (
    tester,
  ) async {
    await launch(tester, siteEnv());
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tapTab(tester, 'Discover');
    expect(find.text('Discover'), findsWidgets);

    await tapTab(tester, 'Startups');
    expect(find.text('The startup directory is on its way'), findsOneWidget);

    await tapTab(tester, 'Profile');
    expect(find.text('Notification preferences'), findsOneWidget);

    // Dark mode applies app-wide.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);

    await tapTab(tester, 'Home');
    expect(find.byType(ArticleHeroCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search finds stories from Home', (tester) async {
    final env = siteEnv();
    await launch(tester, env);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tems');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      env.adapter.requests.any(
        (r) => r.uri.queryParameters['search'] == 'tems',
      ),
      isTrue,
    );
    expect(find.byType(ArticleListTile), findsWidgets);
    expect(GoRouter.of(tester.element(find.byType(TextField))), isNotNull);
  });

  for (final (name, size) in [
    ('phone', const Size(1080, 2340)),
    ('small phone', const Size(720, 1280)),
  ]) {
    testWidgets('$name: screens lay out without overflow at the largest '
        'text size', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await launch(tester, siteEnv());
      // Every onboarding page.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'onboarding $i');
      }
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      for (final tab in ['Discover', 'Startups', 'Saved', 'Profile', 'Home']) {
        await tapTab(tester, tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.tap(find.byType(ArticleHeroCard).first);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'reader');
    });
  }

  testWidgets('a tapped notification opens its story', (tester) async {
    final push = FakeNotifications();
    final container = await launch(tester, siteEnv(), notifications: push);
    await finishOnboarding(container);
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();

    expect(push.started, isTrue);
    expect(push.synced, isNotEmpty);
    push.tap('https://allbiohub.com/tems-biography/');
    await tester.pumpAndSettle();
    expect(find.byType(ArticleScreen), findsOneWidget);

    // Back returns to where the reader was.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a notification tapped at launch opens after the splash', (
    tester,
  ) async {
    final push = FakeNotifications();
    final container = await launch(
      tester,
      siteEnv(),
      notifications: push,
      settle: false,
    );
    await finishOnboarding(container);
    await tester.pump();
    push.tap('https://allbiohub.com/tems-biography/');
    await tester.pump();
    expect(find.byType(ArticleScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.byType(ArticleScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
