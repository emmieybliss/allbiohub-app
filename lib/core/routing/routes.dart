/// App route paths. Keep in sync with app_router.dart.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const discover = '/discover';
  static const startups = '/startups';
  static const saved = '/saved';
  static const profile = '/profile';
  static const search = '/search';
  static const notificationSettings = '/profile/notifications';
  static const startupDirectory = '/startups/directory';

  static String article(int id) => '/article/$id';
  static String articleBySlug(String slug) =>
      '/story/${Uri.encodeComponent(slug)}';
  static String category(String slug) =>
      '/category/${Uri.encodeComponent(slug)}';
  static String tag(String slug) => '/tag/${Uri.encodeComponent(slug)}';
  static String startup(String slug) => '/startup/${Uri.encodeComponent(slug)}';
}
