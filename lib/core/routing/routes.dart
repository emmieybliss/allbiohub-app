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

  // Community (COMMUNITY.md). Shown only when their feature is switched on.
  static const signIn = '/account/sign-in';
  static const chooseUsername = '/account/username';
  static const editProfile = '/me/edit';
  static const accountSettings = '/me/settings';
  static const following = '/me/following';
  static const watchlist = '/me/watchlist';
  static const myComments = '/me/comments';
  static const mySubmissions = '/me/submissions';
  static const notificationCenter = '/me/notifications';
  static const polls = '/polls';
  static const submitStory = '/submit/story';
  static const submitStartup = '/submit/startup';

  static String article(int id) => '/article/$id';
  static String articleBySlug(String slug) =>
      '/story/${Uri.encodeComponent(slug)}';
  static String category(String slug) =>
      '/category/${Uri.encodeComponent(slug)}';
  static String tag(String slug) => '/tag/${Uri.encodeComponent(slug)}';
  static String startup(String slug) => '/startup/${Uri.encodeComponent(slug)}';
  static String articleComments(int id) => '/article/$id/comments';
  static String claimStartup(String slug) =>
      '/startup/${Uri.encodeComponent(slug)}/claim';
  static String userProfile(String uid) => '/u/${Uri.encodeComponent(uid)}';
  static String founder(String slug) => '/founder/${Uri.encodeComponent(slug)}';
}
