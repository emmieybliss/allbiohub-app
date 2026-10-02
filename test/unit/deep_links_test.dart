import 'package:allbiohub/core/routing/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = DeepLinkParser(host: 'allbiohub.com');
  String? at(String url) => parser.locationFor(Uri.parse(url));

  test('maps site URLs to app routes', () {
    expect(at('https://allbiohub.com/'), '/home');
    expect(
      at('https://allbiohub.com/tems-biography/'),
      '/story/tems-biography',
    );
    expect(
      at('https://www.allbiohub.com/tems-biography'),
      '/story/tems-biography',
    );
    expect(at('https://allbiohub.com/startups/'), '/startups');
    expect(at('https://allbiohub.com/startups/page/2/'), '/startups');
    expect(at('https://allbiohub.com/startups/vast/'), '/startup/vast');
    expect(
      at('https://allbiohub.com/category/biography/'),
      '/category/biography',
    );
    expect(
      at('https://allbiohub.com/category/biography/page/3/'),
      '/category/biography',
    );
    expect(at('https://allbiohub.com/tag/afrobeats/'), '/tag/afrobeats');
  });

  test('leaves website-only pages and other sites alone', () {
    expect(at('https://allbiohub.com/wp-admin/'), isNull);
    expect(at('https://allbiohub.com/list-your-startup/'), isNull);
    expect(at('https://allbiohub.com/claim-startup/'), isNull);
    expect(at('https://allbiohub.com/sitemap_index.xml'), isNull);
    expect(at('https://allbiohub.com/2026/09/some/path/'), isNull);
    expect(at('https://example.com/tems-biography/'), isNull);
    expect(at('ftp://allbiohub.com/x'), isNull);
  });
}
