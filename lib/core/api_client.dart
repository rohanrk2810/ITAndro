import 'package:dio/dio.dart';

import 'env.dart';

/// Every request goes through the gateway; no service is addressed directly.
class ApiClient {
  ApiClient({required this.readAccessToken, required this.refresh}) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = readAccessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final req = error.requestOptions;
        final isAuth = req.path.contains('/api/auth/login') || req.path.contains('/api/auth/refresh');
        if (error.response?.statusCode == 401 && req.extra['retried'] != true && !isAuth) {
          final fresh = await refresh();
          if (fresh != null) {
            req.extra['retried'] = true;
            req.headers['Authorization'] = 'Bearer $fresh';
            try {
              return handler.resolve(await dio.fetch(req));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  final String? Function() readAccessToken;
  final Future<String?> Function() refresh;

  final Dio dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
}

/// The message worth showing a person, from any error the client can throw.
String apiErrorMessage(Object error, [String fallback = 'Something went wrong. Please try again.']) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final fields = data['fieldErrors'];
      if (fields is Map && fields.isNotEmpty) {
        return fields.entries.take(4).map((e) => '${e.key}: ${e.value}').join('; ');
      }
      if (data['message'] is String) return data['message'] as String;
    }
    if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the server. Check the connection.';
    }
  }
  return fallback;
}
