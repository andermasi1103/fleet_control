import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final message = _getErrorMessage(err);

    final normalizedError = err.copyWith(
      message: message,
    );

    handler.next(normalizedError);
  }

  String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Tiempo de conexión agotado.';

      case DioExceptionType.sendTimeout:
        return 'Tiempo de envío agotado.';

      case DioExceptionType.receiveTimeout:
        return 'Tiempo de respuesta agotado.';

      case DioExceptionType.transformTimeout:
        return 'Tiempo de procesamiento agotado.';

      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor.';

      case DioExceptionType.badResponse:
        return _getServerMessage(error.response);

      case DioExceptionType.cancel:
        return 'Solicitud cancelada.';

      case DioExceptionType.badCertificate:
        return 'Certificado de seguridad inválido.';

      case DioExceptionType.unknown:
        return 'Ocurrió un error de red.';
    }
  }

  String _getServerMessage(
    Response<dynamic>? response,
  ) {
    if (response == null) {
      return 'El servidor no respondió correctamente.';
    }

    switch (response.statusCode) {
      case 401:
        return 'Sesión no autorizada.';

      case 403:
        return 'No tienes permisos para realizar esta operación.';

      case 404:
        return 'Recurso no encontrado.';

      default:
        if (response.statusCode != null &&
            response.statusCode! >= 500) {
          return 'Error interno del servidor.';
        }

        return 'El servidor rechazó la solicitud.';
    }
  }
}