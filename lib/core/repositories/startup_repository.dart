import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/paginated.dart';
import '../models/startup.dart';
import '../networking/api_client.dart';
import '../networking/app_exception.dart';

/// Thrown when the startup directory API isn't installed on the website, so
/// screens can explain that instead of showing a generic error.
class StartupDirectoryUnavailable implements Exception {
  const StartupDirectoryUnavailable();
}

/// The AllBioHub startup directory.
///
/// The website doesn't expose startups through the WordPress REST API today
/// (see API.md). This repository targets the read-only endpoint proposed in
/// API.md under [AppConfig.startupApiPath]; until it exists every call throws
/// [StartupDirectoryUnavailable].
class StartupRepository {
  StartupRepository({required this._client, required AppConfig config})
    : _base = config.startupApiBase;

  final ApiClient _client;
  final String _base;

  Future<Paginated<Startup>> list(
    StartupQuery query, {
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final response = await _get(
      '$_base/startups',
      query: {...query.toQuery(), 'page': page, 'per_page': perPage},
      maxAge: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! List) throw const AppException(AppErrorKind.badResponse);
    return Paginated(
      items: _startups(data),
      page: page,
      totalPages: response.totalPages,
      total: response.total,
      stale: response.stale,
    );
  }

  Future<Startup> bySlug(String slug, {bool forceRefresh = false}) async {
    final response = await _get(
      '$_base/startups/${Uri.encodeComponent(slug)}',
      maxAge: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.badResponse);
    }
    return Startup.fromJson(data);
  }

  /// Filter values the directory actually contains.
  Future<StartupFilterOptions> filters() async {
    final response = await _get(
      '$_base/startups/filters',
      maxAge: const Duration(hours: 6),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.badResponse);
    }
    return StartupFilterOptions.fromJson(data);
  }

  Future<ApiResponse> _get(
    String url, {
    Map<String, Object?> query = const {},
    required Duration maxAge,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _client.getJson(
        url,
        query: query,
        maxAge: maxAge,
        forceRefresh: forceRefresh,
        cancelToken: cancelToken,
      );
    } on AppException catch (e) {
      // A 404 on the collection route means the API isn't installed.
      if (e.kind == AppErrorKind.notFound && url.endsWith('/startups')) {
        throw const StartupDirectoryUnavailable();
      }
      if (e.kind == AppErrorKind.notFound && url.endsWith('/filters')) {
        throw const StartupDirectoryUnavailable();
      }
      rethrow;
    }
  }

  static List<Startup> _startups(List<dynamic> data) {
    final result = <Startup>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        result.add(Startup.fromJson(item));
      } on Object {
        // Skip one malformed record rather than failing the list.
      }
    }
    return result;
  }
}
