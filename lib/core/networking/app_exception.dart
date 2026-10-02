import 'package:dio/dio.dart';

enum AppErrorKind {
  offline,
  timeout,
  notFound,
  server,
  badResponse,
  cancelled,
  unknown,
}

/// A failure that is safe to show to people. Technical detail stays in
/// [debugDetail] and is only logged in debug builds.
class AppException implements Exception {
  const AppException(this.kind, {this.debugDetail});

  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      final kind = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => AppErrorKind.timeout,
        DioExceptionType.connectionError => AppErrorKind.offline,
        DioExceptionType.cancel => AppErrorKind.cancelled,
        DioExceptionType.badResponse => switch (error.response?.statusCode) {
          404 => AppErrorKind.notFound,
          // WordPress answers 400 for a page number past the last page.
          400 when _wpCode(error) == 'rest_post_invalid_page_number' =>
            AppErrorKind.notFound,
          final int code when code >= 500 => AppErrorKind.server,
          _ => AppErrorKind.badResponse,
        },
        DioExceptionType.badCertificate => AppErrorKind.unknown,
        DioExceptionType.unknown =>
          error.error.toString().contains('SocketException')
              ? AppErrorKind.offline
              : AppErrorKind.unknown,
      };
      return AppException(kind, debugDetail: '${error.type}: ${error.message}');
    }
    if (error is FormatException || error is TypeError) {
      return AppException(AppErrorKind.badResponse, debugDetail: '$error');
    }
    return AppException(AppErrorKind.unknown, debugDetail: '$error');
  }

  static String? _wpCode(DioException e) {
    final data = e.response?.data;
    return data is Map ? data['code'] as String? : null;
  }

  final AppErrorKind kind;
  final String? debugDetail;

  bool get isOffline =>
      kind == AppErrorKind.offline || kind == AppErrorKind.timeout;

  String get title => switch (kind) {
    AppErrorKind.offline => "You're offline",
    AppErrorKind.timeout => 'The connection is slow',
    AppErrorKind.notFound => 'Not found',
    _ => 'Something went wrong',
  };

  String get message => switch (kind) {
    AppErrorKind.offline => 'Check your connection and try again.',
    AppErrorKind.timeout =>
      'This is taking longer than usual. Please try again.',
    AppErrorKind.notFound => "We couldn't find what you were looking for.",
    _ => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'AppException($kind, $debugDetail)';
}
