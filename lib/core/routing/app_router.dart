import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/articles/article_screen.dart';
import '../../features/articles/topic_feed_screen.dart';
import '../../features/bookmarks/saved_screen.dart';
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
  r'startups(/directory)?|(article|story|category|tag|startup)/[^/]+)$',
);

final routerProvider = Provider<GoRouter>((ref) {
  final parser = ref.watch(deepLinkParserProvider);
  final siteUrl = Uri.parse(ref.watch(appConfigProvider).siteUrl);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final path = state.uri.path;
      if (_appRoutePattern.hasMatch(path)) return null;
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
