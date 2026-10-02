import 'package:allbiohub/core/models/paginated.dart';
import 'package:allbiohub/core/networking/app_exception.dart';
import 'package:allbiohub/shared/paged_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> requested;
  late bool failNext;

  NotifierProvider<PagedListNotifier<int>, PagedState<int>> provider({
    bool autoLoad = true,
  }) => NotifierProvider(
    () => PagedListNotifier<int>(
      (ref, page, force) async {
        requested.add(page);
        if (failNext) {
          failNext = false;
          throw const AppException(AppErrorKind.offline);
        }
        // Page 2 repeats item 3 to simulate a shifted list.
        final items = page == 1
            ? [1, 2, 3]
            : page == 2
            ? [3, 4, 5]
            : <int>[];
        return Paginated(items: items, page: page, totalPages: 2);
      },
      idOf: (i) => i,
      autoLoad: autoLoad,
    ),
  );

  setUp(() {
    requested = [];
    failNext = false;
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('loads the first page, then more, de-duplicating', () async {
    final container = ProviderContainer();
    final p = provider();
    container.listen(p, (_, _) {});
    expect(container.read(p).isInitialLoading, isTrue);
    await settle();
    expect(container.read(p).items, [1, 2, 3]);
    await container.read(p.notifier).loadMore();
    final s = container.read(p);
    expect(s.items, [1, 2, 3, 4, 5]);
    expect(s.hasMore, isFalse);
    await container.read(p.notifier).loadMore();
    expect(requested, [1, 2], reason: 'no request past the last page');
  });

  test('first-page failure shows an error, retry recovers', () async {
    failNext = true;
    final container = ProviderContainer();
    final p = provider();
    container.listen(p, (_, _) {});
    await settle();
    expect(container.read(p).error, isA<AppException>());
    await container.read(p.notifier).retry();
    expect(container.read(p).items, [1, 2, 3]);
  });

  test('load-more failure keeps items and offers retry', () async {
    final container = ProviderContainer();
    final p = provider();
    container.listen(p, (_, _) {});
    await settle();
    failNext = true;
    await container.read(p.notifier).loadMore();
    expect(container.read(p).items, [1, 2, 3]);
    expect(container.read(p).loadMoreError, isNotNull);
    await container.read(p.notifier).retry();
    expect(container.read(p).items, [1, 2, 3, 4, 5]);
  });

  test('lazy lists wait for the first loadMore', () async {
    final container = ProviderContainer();
    final p = provider(autoLoad: false);
    container.listen(p, (_, _) {});
    await settle();
    expect(requested, isEmpty);
    await container.read(p.notifier).loadMore();
    expect(container.read(p).items, [1, 2, 3]);
  });
}
