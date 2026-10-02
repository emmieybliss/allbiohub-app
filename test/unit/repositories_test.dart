import 'package:allbiohub/core/cache/cache_store.dart';
import 'package:allbiohub/core/config/app_config.dart';
import 'package:allbiohub/core/models/startup.dart';
import 'package:allbiohub/core/networking/api_client.dart';
import 'package:allbiohub/core/networking/app_exception.dart';
import 'package:allbiohub/core/repositories/article_repository.dart';
import 'package:allbiohub/core/repositories/startup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';
import '../helpers/fake_http.dart';

const config = AppConfig(
  siteUrl: 'https://allbiohub.com',
  environment: 'test',
  startupApiPath: '/wp-json/allbiohub/v1',
);

void main() {
  late FakeAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = FakeAdapter();
    client = ApiClient(dio: fakeDio(adapter), cache: MemoryCacheStore());
  });

  group('ArticleRepository', () {
    late ArticleRepository repo;
    setUp(
      () => repo = ArticleRepository(
        client: client,
        config: config,
        taxonomy: TaxonomyRepository(client: client, config: config),
      ),
    );

    test(
      'fills in image, author and categories when _embed is ignored',
      () async {
        final embedded = wpPost()['_embedded'] as Map<String, dynamic>;
        adapter.routes
          ..['/wp-json/wp/v2/posts'] = FakeResponse([
            wpPost(id: 1)..remove('_embedded'),
            wpPost(id: 2, withImage: false)..remove('_embedded'),
          ])
          ..['/wp-json/wp/v2/media'] = FakeResponse([
            (embedded['wp:featuredmedia'] as List).first,
          ])
          ..['/wp-json/wp/v2/users'] = FakeResponse([
            (embedded['author'] as List).first,
          ])
          ..['/wp-json/wp/v2/categories'] = FakeResponse(wpCategories());
        final items = (await repo.latest()).items;
        expect(items[0].image?.alt, 'Tems performing');
        expect(items[0].author?.name, 'Ada Obi');
        expect(items[0].primaryCategory?.slug, 'celebrity-news');
        expect(items[1].image, isNull, reason: 'no featured media id');
        final mediaRequest = adapter.requests.firstWhere(
          (r) => r.uri.path.endsWith('/media'),
        );
        expect(mediaRequest.queryParameters['include'], '12882');
      },
    );

    test(
      'a failing detail request leaves placeholders, not an error',
      () async {
        adapter.routes
          ..['/wp-json/wp/v2/posts'] = FakeResponse([
            wpPost(id: 1)..remove('_embedded'),
          ])
          ..['/wp-json/wp/v2/media'] = const FakeResponse({
            'code': 'x',
          }, status: 500);
        final items = (await repo.latest()).items;
        expect(items.single.image, isNull);
        expect(items.single.title, isNotEmpty);
      },
    );

    test('latest returns a page and requests a slim, embedded list', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = FakeResponse(
        [wpPost(id: 1), wpPost(id: 2)],
        headers: const {'x-wp-totalpages': '3'},
      );
      final page = await repo.latest(page: 1, categoryId: 137);
      expect(page.items.map((a) => a.id), [1, 2]);
      expect(page.hasMore, isTrue);
      final q = adapter.requests.single.queryParameters;
      expect(q['categories'], 137);
      expect(q['_embed'], 'author,wp:featuredmedia,wp:term');
      expect(q['_fields'], isNot(contains('content')));
    });

    test('last page reports no more', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = FakeResponse(
        [wpPost()],
        headers: const {'x-wp-totalpages': '3'},
      );
      final page = await repo.latest(page: 3);
      expect(page.hasMore, isFalse);
    });

    test('skips malformed posts instead of failing the list', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = FakeResponse([
        wpPost(id: 1),
        {'id': 'bad'},
        'junk',
      ]);
      final page = await repo.latest();
      expect(page.items.map((a) => a.id), [1]);
    });

    test('empty response is an empty page', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = const FakeResponse([]);
      final page = await repo.latest();
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('non-list response is a bad response', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = const FakeResponse({
        'unexpected': true,
      });
      await expectLater(
        repo.latest(),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.badResponse,
          ),
        ),
      );
    });

    test('a page past the end is an empty last page, not an error', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = const FakeResponse({
        'code': 'rest_post_invalid_page_number',
        'message': 'The page number requested is larger than the number of pages available.',
      }, status: 400);
      final page = await repo.latest(page: 4);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('bySlug throws not found for an unknown slug', () async {
      adapter.routes['/wp-json/wp/v2/posts'] = const FakeResponse([]);
      await expectLater(
        repo.bySlug('nope'),
        throwsA(
          isA<AppException>().having(
            (e) => e.kind,
            'kind',
            AppErrorKind.notFound,
          ),
        ),
      );
    });

    test('byId includes content', () async {
      adapter.routes['/wp-json/wp/v2/posts/101'] = FakeResponse(wpPost());
      final a = await repo.byId(101);
      expect(a.contentHtml, isNotNull);
      expect(
        adapter.requests.single.queryParameters['_fields'],
        contains('content'),
      );
    });
  });

  group('TaxonomyRepository', () {
    test('hides empty and internal categories', () async {
      adapter.routes['/wp-json/wp/v2/categories'] = FakeResponse(
        wpCategories(),
      );
      final repo = TaxonomyRepository(client: client, config: config);
      final slugs = (await repo.categories()).map((c) => c.slug);
      expect(slugs, [
        'around-the-web',
        'biography',
        'celebrity-news',
        'money-career',
        'reviews',
        'startup-founders-innovator',
        'women-in-tech',
      ]);
    });
  });

  group('StartupRepository', () {
    late StartupRepository repo;
    setUp(() => repo = StartupRepository(client: client, config: config));

    test(
      'reports the directory as unavailable when the API is missing',
      () async {
        await expectLater(
          repo.list(const StartupQuery()),
          throwsA(isA<StartupDirectoryUnavailable>()),
        );
        await expectLater(
          repo.filters(),
          throwsA(isA<StartupDirectoryUnavailable>()),
        );
      },
    );

    test('parses startups and sends only set filters', () async {
      adapter.routes['/wp-json/allbiohub/v1/startups'] = FakeResponse(
        [
          startupJson(verified: true),
          {'bad': true},
        ],
        headers: const {'x-wp-totalpages': '1'},
      );
      final page = await repo.list(
        const StartupQuery(country: 'Nigeria', verified: true),
      );
      final s = page.items.single;
      expect(s.name, 'Vast');
      expect(s.verified, isTrue);
      expect(s.claimed, isFalse);
      expect(s.city, isNull, reason: 'blank strings become null');
      expect(s.location, 'United States');
      expect(s.socialLinks.keys, ['linkedin'], reason: 'empty links dropped');
      final q = adapter.requests.single.queryParameters;
      expect(q['country'], 'Nigeria');
      expect(q['verified'], 1);
      expect(q.containsKey('industry'), isFalse);
    });

    test('parses filter options in either string or object form', () async {
      adapter.routes['/wp-json/allbiohub/v1/startups/filters'] =
          const FakeResponse({
            'industries': [
              {'value': 'saas', 'label': 'SaaS', 'count': 12},
              'Media',
            ],
            'countries': ['Nigeria'],
          });
      final f = await repo.filters();
      expect(f.industries.map((o) => o.label), ['SaaS', 'Media']);
      expect(f.industries.first.count, 12);
      expect(f.countries.single.value, 'Nigeria');
      expect(f.stages, isEmpty);
    });
  });
}
