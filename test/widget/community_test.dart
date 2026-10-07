// Community features in the real app, with an in-memory backend.
import 'package:allbiohub/app.dart';
import 'package:allbiohub/core/community/feature_flags.dart';
import 'package:allbiohub/core/community/models.dart';
import 'package:allbiohub/core/routing/app_router.dart';
import 'package:allbiohub/core/routing/routes.dart';
import 'package:allbiohub/features/account/sign_in_screen.dart';
import 'package:allbiohub/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';
import '../helpers/fake_community.dart';
import '../helpers/fake_http.dart';
import '../helpers/test_app.dart';

TestEnv _site() => TestEnv({
  '/wp-json/wp/v2/posts': FakeResponse(
    [wpPost()],
    headers: const {'x-wp-totalpages': '1'},
  ),
  '/wp-json/wp/v2/posts/101': FakeResponse(wpPost()),
  '/wp-json/wp/v2/categories': FakeResponse(wpCategories()),
  '/wp-json/wp/v2/tags': const FakeResponse([]),
});

Future<ProviderContainer> _launch(
  WidgetTester tester, {
  FakeAuth? auth,
  FakeCommunity? api,
  Set<Feature>? features,
  bool community = true,
}) async {
  AppImage.disableNetwork = true;
  final a = auth ?? FakeAuth();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ..._site().overrides(),
        if (community)
          ...communityOverrides(
            auth: a,
            api: api ?? FakeCommunity(auth: a),
            features: features,
          ),
      ],
      child: const AllBioHubApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AllBioHubApp)));
}

Future<void> _go(
  WidgetTester tester,
  ProviderContainer c,
  String location,
) async {
  c.read(routerProvider).push(location);
  await tester.pumpAndSettle();
}

Future<FakeCommunity> _member(FakeAuth auth) async {
  final api = FakeCommunity(auth: auth);
  await api.createProfile(username: 'reader', displayName: 'Reader');
  return api;
}

void main() {
  testWidgets('with community features off, the app looks as before', (
    tester,
  ) async {
    final c = await _launch(tester, community: false);
    c.read(routerProvider).go(Routes.profile);
    await tester.pumpAndSettle();
    expect(find.text('Join the AllBioHub community'), findsNothing);
    await _go(tester, c, Routes.article(101));
    expect(find.text('What did you think?'), findsNothing);
    expect(find.text('Comments'), findsNothing);
  });

  testWidgets('guests can read; reacting asks them to sign in', (tester) async {
    final c = await _launch(tester);
    c.read(routerProvider).go(Routes.profile);
    await tester.pumpAndSettle();
    expect(find.text('Join the AllBioHub community'), findsOneWidget);

    await _go(tester, c, Routes.article(101));
    await tester.scrollUntilVisible(
      find.text('Love'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('What did you think?'), findsOneWidget);
    await tester.tap(find.text('Love'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Sign in to react to stories.'), findsOneWidget);
  });

  testWidgets('members react at once', (tester) async {
    final auth = FakeAuth(signedIn: verifiedUser());
    final api = await _member(auth);
    final c = await _launch(tester, auth: auth, api: api);
    await _go(tester, c, Routes.article(101));
    await tester.scrollUntilVisible(
      find.text('Love'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Love'));
    await tester.pumpAndSettle();
    expect(api.myReactions[101], ReactionType.love);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('offline actions say so and change nothing', (tester) async {
    final auth = FakeAuth(signedIn: verifiedUser());
    final api = await _member(auth);
    final c = await _launch(tester, auth: auth, api: api);
    api.offline = true;
    await _go(tester, c, Routes.article(101));
    await tester.scrollUntilVisible(
      find.text('Wow'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Wow'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You are offline. Connect to the internet to perform this action.',
      ),
      findsOneWidget,
    );
    expect(find.text('Wow'), findsOneWidget, reason: 'the count rolled back');
    expect(api.myReactions, isEmpty);
  });

  testWidgets('story submissions go to editors, never straight to the site', (
    tester,
  ) async {
    final auth = FakeAuth(signedIn: verifiedUser());
    final api = await _member(auth);
    final c = await _launch(tester, auth: auth, api: api);
    await _go(tester, c, Routes.submitStory);
    expect(
      find.textContaining('Nothing is published automatically'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title *'),
      'Lagos startup raises seed round',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description *'),
      'A Lagos fintech closed a seed round led by local investors this week.',
    );
    final submit = find.text('Submit for review');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your submission has been received and is awaiting editorial review.',
      ),
      findsOneWidget,
    );
    expect(api.submissions.single.$1, 'story');
    expect(
      api.submissions.single.$2['title'],
      'Lagos startup raises seed round',
    );
  });

  testWidgets('a switched-off feature can\'t be opened from a link', (
    tester,
  ) async {
    final c = await _launch(tester, features: {Feature.accounts});
    await _go(tester, c, Routes.polls);
    expect(find.text('Polls'), findsNothing);
  });
}
