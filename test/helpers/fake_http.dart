import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned HTTP response for [FakeAdapter].
class FakeResponse {
  const FakeResponse(this.body, {this.status = 200, this.headers = const {}});

  final Object? body;
  final int status;
  final Map<String, String> headers;
}

/// Dio adapter that answers from a route table (path → response) and
/// records every request. Throws a connection error for unknown paths when
/// [offline] is true.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter([Map<String, FakeResponse>? routes]) : routes = routes ?? {};

  final Map<String, FakeResponse> routes;
  final List<RequestOptions> requests = [];
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final response = routes[options.uri.path];
    if (response == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 'rest_no_route',
          'message': 'No route was found matching the URL and request method.',
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final e in response.headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;
