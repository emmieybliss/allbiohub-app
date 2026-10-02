import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../cache/cache_store.dart';
import 'app_exception.dart';

/// Decoded JSON plus WordPress pagination headers.
class ApiResponse {
  const ApiResponse({
    required this.data,
    this.total,
    this.totalPages,
    this.fromCache = false,
    this.stale = false,
  });

  final Object? data;
  final int? total;
  final int? totalPages;

  /// Served from the local cache instead of the network.
  final bool fromCache;

  /// Served from cache because the network failed; may be out of date.
  final bool stale;

  Map<String, dynamic> toCache() => {'d': data, 'n': total, 'p': totalPages};

  static ApiResponse fromCacheEntry(CacheEntry entry, {required bool stale}) =>
      ApiResponse(
        data: entry.payload['d'],
        total: entry.payload['n'] as int?,
        totalPages: entry.payload['p'] as int?,
        fromCache: true,
        stale: stale,
      );
}

/// The only place the app talks HTTP. Every request goes through [getJson],
/// which applies the cache policy:
///
/// 1. A cached response younger than `maxAge` is returned without a request.
/// 2. Otherwise the network is used and the response cached.
/// 3. If the network fails and a cached copy exists (of any age), it is
///    returned with `stale: true` so screens can show an offline notice.
class ApiClient {
  ApiClient({
    required this._dio,
    required this._cache,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final CacheStore _cache;
  final DateTime Function() _clock;

  static Dio createDio({required String userAgent}) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json', 'User-Agent': userAgent},
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (o) => debugPrint('$o'),
        ),
      );
    }
    return dio;
  }

  Future<ApiResponse> getJson(
    String url, {
    Map<String, Object?> query = const {},
    Duration maxAge = const Duration(minutes: 5),
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final params = <String, Object>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value!,
    };
    final key = Uri.parse(url)
        .replace(queryParameters: params.map((k, v) => MapEntry(k, '$v')))
        .toString();

    final cached = _cache.read(key);
    if (!forceRefresh && cached != null && cached.isFresh(maxAge, _clock())) {
      return ApiResponse.fromCacheEntry(cached, stale: false);
    }

    try {
      final response = await _dio.get<Object?>(
        url,
        queryParameters: params,
        cancelToken: cancelToken,
      );
      final result = ApiResponse(
        data: response.data,
        total: _intHeader(response.headers, 'x-wp-total'),
        totalPages: _intHeader(response.headers, 'x-wp-totalpages'),
      );
      await _cache.write(key, result.toCache());
      return result;
    } catch (error) {
      final failure = AppException.from(error);
      if (kDebugMode) {
        debugPrint('ApiClient: $key failed: ${failure.debugDetail}');
      }
      if (cached != null &&
          failure.kind != AppErrorKind.cancelled &&
          failure.kind != AppErrorKind.notFound) {
        return ApiResponse.fromCacheEntry(cached, stale: true);
      }
      throw failure;
    }
  }

  static int? _intHeader(Headers headers, String name) =>
      int.tryParse(headers.value(name) ?? '');
}
