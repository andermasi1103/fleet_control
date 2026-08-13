import 'package:dio/dio.dart';

import '../../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._secureStorage,
  });

  final SecureStorageService _secureStorage;

  static const String accessTokenKey = 'access_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _secureStorage.read(accessTokenKey);

      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // No bloqueamos la petición si falla la lectura del token.
    }

    handler.next(options);
  }
}