import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_settings_screen.dart';
import '../../features/account/edit_profile_screen.dart';
import '../../features/account/sign_in_screen.dart';
import '../../features/account/username_screen.dart';
import '../../features/articles/article_screen.dart';
import '../../features/articles/topic_feed_screen.dart';
import '../../features/bookmarks/saved_screen.dart';
import '../../features/community/comments_screen.dart';
import '../../features/community/following_screen.dart';
import '../../features/community/founder_screen.dart';
import '../../features/community/notification_center_screen.dart';
import '../../features/community/polls_screen.dart';
import '../../features/community/submissions_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/notification_settings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/startups/startup_directory_screen.dart';
import '../../features/startups/startup_profile_screen.dart';
import '../../features/startups/startups_home_screen.dart';
import '../community/community_providers.dart';
import '../community/feature_flags.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../models/startup.dart';
import '../providers.dart';
import 'deep_links.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final deepLinkParserProvider = Provider<DeepLinkParser>(
  (ref) => DeepLinkParser(host: ref.watch(appConfigProvider).siteHost),
);

/// Paths that are app routes. Anything else is treated as an incoming
/// allbiohub.com URL and translated by [DeepLinkParser].
final _appRoutePattern = RegExp(
  r'^/(splash|onboarding|home|discover|saved|search|profile(/notifications)?|'
  r'startups(/directory)?|(article|story|category|tag|startup)/[^/]+|'
  r'article/[0-9]+/comments|startup/[^/]+/claim|(u|founder)/[^/]+|'
  r'account/(sign-in|username)|polls|submit/(story|startup)|'
  r'me/(edit|settings|following|watchlist|comments|submissions|notifications))$',
);

/// Community pages and the switch each needs. While it is off (for
/// example from an old notification), the page sends people Home.
Feature? _featureFor(String path) => switch (path) {
  _ when path.startsWith('/account/') || path.startsWith('/me/') =>
    Feature.accounts,
  _ when path.startsWith('/u/') => Feature.profiles,
  _ when path.endsWith('/comments') => Feature.comments,
  _ when path.endsWith('/claim') => Feature.startupClaims,
  '/polls' => Feature.polls,
  '/submit/story' => Feature.storySubmissions,
  '/submit/startup' => Feature.startupSubmissions,
  _ when path.startsWith('/founder/') => Feature.founderFollows,
  _ => null,
};

final routerProvider = Provider<GoRouter>((ref) {
  final parser = ref.watch(deepLinkParserProvider);
  final siteUrl = Uri.parse(ref.watch(appConfigProvider).siteUrl);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final path = state.uri.path;
      if (_appRoutePattern.hasMatch(path)) {
        final feature = _featureFor(path);
        if (feature != null && !ref.read(featureFlagsProvider).isOn(feature)) {
          return Routes.home;
        }
        return null;
      }
      final incoming = siteUrl.replace(
        path: path,
        query: state.uri.query.isEmpty ? null : state.uri.query,
      );
      return parser.locationFor(incoming) ?? Routes.home;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.discover,
                builder: (_, _) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.startups,
                builder: (_, _) => const StartupsHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'directory',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => StartupDirectoryScreen(
                      initialQuery: state.extra is StartupQuery
                          ? state.extra! as StartupQuery
                          : const StartupQuery(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.saved,
                builder: (_, _) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const NotificationSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _fadePage(state, const SearchScreen()),
      ),
      GoRoute(
        path: '/article/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ArticleScreen(
          id: int.tryParse(state.pathParameters['id']!),
          preview: state.extra is Article ? state.extra! as Article : null,
        ),
      ),
      GoRoute(
        path: '/story/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            ArticleScreen(slug: state.pathParameters['slug']),
      ),
      GoRoute(
        path: '/category/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TopicFeedScreen(
          slug: state.pathParameters['slug']!,
          kind: TermKind.category,
          preview: state.extra is Category ? state.extra! as Category : null,
        ),
      ),
      GoRoute(
        path: '/tag/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TopicFeedScreen(
          slug: state.pathParameters['slug']!,
          kind: TermKind.tag,
          preview: state.extra is Category ? state.extra! as Category : null,
        ),
      ),
      GoRoute(
        path: '/startup/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            StartupProfileScreen(slug: state.pathParameters['slug']!),
        routes: [
          GoRoute(
            path: 'claim',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, state) =>
                ClaimStartupScreen(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: '/article/:id/comments',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => CommentsScreen(
          articleId: int.parse(state.pathParameters['id']!),
          title: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/founder/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => FounderScreen(
          slug: state.pathParameters['slug']!,
          args: state.extra is FounderArgs ? state.extra! as FounderArgs : null,
        ),
      ),
      GoRoute(
        path: '/u/:uid',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            PublicProfileScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: Routes.signIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => SignInScreen(
          reason: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: Routes.chooseUsername,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => UsernameScreen(changing: state.extra == true),
      ),
      GoRoute(
        path: Routes.polls,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PollsScreen(),
      ),
      GoRoute(
        path: Routes.submitStory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SubmitStoryScreen(),
      ),
      GoRoute(
        path: Routes.submitStartup,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SubmitStartupScreen(),
      ),
      for (final (path, page) in <(String, Widget)>[
        (Routes.editProfile, const EditProfileScreen()),
        (Routes.accountSettings, const AccountSettingsScreen()),
        (Routes.following, const FollowingScreen()),
        (Routes.watchlist, const WatchlistScreen()),
        (Routes.myComments, const MyCommentsScreen()),
        (Routes.mySubmissions, const MySubmissionsScreen()),
        (Routes.notificationCenter, const NotificationCenterScreen()),
      ])
        GoRoute(
          path: path,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => page,
        ),
    ],
  );
});

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
