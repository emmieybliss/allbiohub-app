import 'routes.dart';

/// Maps allbiohub.com URLs to in-app locations, so App Links, notification
/// payloads and links inside articles open natively.
///
/// Returns null for URLs the app doesn't handle (other sites, admin, forms
/// such as List Your Startup); callers open those in the browser.
class DeepLinkParser {
  const DeepLinkParser({required this.host});

  final String host;

  /// First path segments that are website pages or system paths, not stories.
  static const _reserved = {
    'wp-admin',
    'wp-content',
    'wp-includes',
    'wp-json',
    'wp-login.php',
    'feed',
    'author',
    'page',
    'search',
    'app',
    'list-your-startup',
    'claim-startup',
    'startup-account',
    'startup-dashboard',
    'startup-pricing',
    'submit-a-story',
    'terms-and-conditions',
    'privacy-policy',
    'contact',
    'about',
    'youtube-resources',
  };

  bool isSiteUrl(Uri uri) {
    final h = uri.host.toLowerCase();
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        (h == host || h == 'www.$host');
  }

  String? locationFor(Uri uri) {
    if (!isSiteUrl(uri)) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return Routes.home;

    final first = segments.first.toLowerCase();
    switch (first) {
      case 'startups':
        if (segments.length == 1 || segments[1] == 'page') {
          return Routes.startups;
        }
        return Routes.startup(segments[1]);
      case 'category':
        // Nested categories put the child last: /category/parent/child/.
        final rest = segments.skip(1).where((s) => s != 'page').toList();
        if (rest.isEmpty) return Routes.discover;
        return Routes.category(_lastNonNumeric(rest));
      case 'tag':
        if (segments.length < 2) return Routes.discover;
        return Routes.tag(segments[1]);
    }
    if (_reserved.contains(first) || first.contains('.')) return null;
    // Posts live at /{slug}/ (Rank Math/WordPress "post name" permalinks).
    if (segments.length == 1) return Routes.articleBySlug(segments.first);
    return null;
  }

  static String _lastNonNumeric(List<String> segments) => segments.lastWhere(
    (s) => int.tryParse(s) == null,
    orElse: () => segments.first,
  );
}
