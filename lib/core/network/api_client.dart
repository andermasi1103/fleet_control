import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;
}

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Options _options({String? bearerToken, Options? options}) {
    final headers = <String, dynamic>{...?options?.headers};
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    return (options ?? Options()).copyWith(headers: headers);
  }

  Future<Response<T>> _request<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      final data = error.response?.data;
      final payload = data is Map ? Map<String, dynamic>.from(data) : null;
      throw ApiException(
        statusCode: error.response?.statusCode,
        code: payload?['error']?.toString(),
        message:
            payload?['message']?.toString() ??
            error.message ??
            'No fue posible completar la solicitud.',
      );
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? bearerToken,
  }) {
    return _request(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: _options(bearerToken: bearerToken, options: options),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? bearerToken,
  }) {
    return _request(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _options(bearerToken: bearerToken, options: options),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? bearerToken,
  }) {
    return _request(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _options(bearerToken: bearerToken, options: options),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? bearerToken,
  }) {
    return _request(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _options(bearerToken: bearerToken, options: options),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    String? bearerToken,
  }) {
    return _request(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _options(bearerToken: bearerToken, options: options),
        cancelToken: cancelToken,
      ),
    );
  }
}
