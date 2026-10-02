import 'package:allbiohub/core/cache/cache_store.dart';
import 'package:allbiohub/core/networking/api_client.dart';
import 'package:allbiohub/core/networking/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http.dart';

void main() {
  late FakeAdapter adapter;
  late MemoryCacheStore cache;
  late DateTime now;
  late ApiClient client;

  setUp(() {
    adapter = FakeAdapter({
      '/wp-json/wp/v2/posts': const FakeResponse(
        [
          {'id': 1},
        ],
        headers: {'x-wp-total': '42', 'x-wp-totalpages': '5'},
      ),
    });
    cache = MemoryCacheStore();
    now = DateTime.now();
    client = ApiClient(dio: fakeDio(adapter), cache: cache, clock: () => now);
  });

  const url = 'https://allbiohub.com/wp-json/wp/v2/posts';

  test('reads pagination headers', () async {
    final r = await client.getJson(url, query: {'page': 1});
    expect(r.data, [
      {'id': 1},
    ]);
    expect(r.total, 42);
    expect(r.totalPages, 5);
    expect(r.fromCache, isFalse);
  });

  test('serves fresh cache without a request', () async {
    await client.getJson(url, query: {'page': 1});
    final r = await client.getJson(url, query: {'page': 1});
    expect(r.fromCache, isTrue);
    expect(r.stale, isFalse);
    expect(adapter.requests, hasLength(1));
  });

  test('refetches when the cache is older than maxAge or forced', () async {
    await client.getJson(url, maxAge: const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 6));
    await client.getJson(url, maxAge: const Duration(minutes: 5));
    await client.getJson(url, forceRefresh: true);
    expect(adapter.requests, hasLength(3));
  });

  test('falls back to stale cache when offline', () async {
    await client.getJson(url);
    adapter.offline = true;
    final r = await client.getJson(url, forceRefresh: true);
    expect(r.stale, isTrue);
    expect(r.totalPages, 5);
  });

  test('throws a friendly offline error with no cache', () async {
    adapter.offline = true;
    await expectLater(
      client.getJson(url),
      throwsA(
        isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.offline),
      ),
    );
  });

  test('maps 404 and 500 responses', () async {
    adapter.routes['/boom'] = const FakeResponse({'code': 'x'}, status: 500);
    await expectLater(
      client.getJson('https://allbiohub.com/missing'),
      throwsA(
        isA<AppException>().having(
          (e) => e.kind,
          'kind',
          AppErrorKind.notFound,
        ),
      ),
    );
    await expectLater(
      client.getJson('https://allbiohub.com/boom'),
      throwsA(
        isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.server),
      ),
    );
  });

  test('error messages never expose technical detail', () {
    const e = AppException(
      AppErrorKind.server,
      debugDetail: 'DioException 500',
    );
    expect(e.message, isNot(contains('Dio')));
    expect(e.message, 'Something went wrong. Please try again.');
  });

  test('drops null query parameters', () async {
    await client.getJson(url, query: {'page': 2, 'categories': null});
    expect(adapter.requests.single.queryParameters, {'page': 2});
  });
}
