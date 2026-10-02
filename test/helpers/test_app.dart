import 'package:allbiohub/core/cache/cache_store.dart';
import 'package:allbiohub/core/cache/local_store.dart';
import 'package:allbiohub/core/networking/api_client.dart';
import 'package:allbiohub/core/providers.dart';
import 'package:allbiohub/core/theme/app_theme.dart';
import 'package:allbiohub/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http.dart';

/// Everything a widget test needs: a fake network and in-memory storage.
class TestEnv {
  TestEnv([Map<String, FakeResponse>? routes]) : adapter = FakeAdapter(routes);

  final FakeAdapter adapter;
  final cache = MemoryCacheStore();
  final bookmarks = MemoryLocalStore();
  final settings = MemoryLocalStore();

  List overrides() => [
    apiClientProvider.overrideWithValue(
      ApiClient(dio: fakeDio(adapter), cache: cache),
    ),
    cacheStoreProvider.overrideWithValue(cache),
    bookmarkStoreProvider.overrideWithValue(bookmarks),
    settingsStoreProvider.overrideWithValue(settings),
  ];
}

/// Pumps [child] inside the app theme with a fake environment.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required TestEnv env,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  AppImage.disableNetwork = true;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [...env.overrides()],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: child,
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byWidget(child)));
}
