import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';

class ProfileDataSource {
  ProfileDataSource(this._client);

  final ApiClient _client;

  Future<void> changePassword({
    required String sessionToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/api/profile/password',
        bearerToken: sessionToken,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on ApiException catch (error) {
      throw Failure(
        message: _message(error.statusCode),
        statusCode: error.statusCode,
        type: error.statusCode == 401
            ? FailureType.sessionExpired
            : error.statusCode == 403
            ? FailureType.insufficientPermissions
            : FailureType.network,
      );
    }
  }

  String _message(int? status) {
    switch (status) {
      case 403:
        return 'La contraseña actual no es correcta.';
      case 401:
        return 'Tu sesión ha vencido. Inicia sesión nuevamente.';
      case 404:
        return 'No fue posible encontrar tu usuario.';
      case 400:
        return 'Revisa los datos ingresados.';
      default:
        return 'No fue posible cambiar la contraseña.';
    }
  }
}
