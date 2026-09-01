import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';

class DriverPresenceDataSource {
  DriverPresenceDataSource(this._client);

  final ApiClient _client;

  Future<void> heartbeat({required String sessionToken}) async {
    try {
      await _client.post<void>(
        '/api/driver/presence',
        bearerToken: sessionToken,
        data: const {},
      );
    } on ApiException catch (error) {
      throw Failure(
        message: error.statusCode == 401
            ? 'Tu sesión ha vencido. Inicia sesión nuevamente.'
            : error.statusCode == 403
            ? 'No tienes permiso para informar presencia.'
            : 'No fue posible actualizar tu presencia.',
        statusCode: error.statusCode,
        type: error.statusCode == 401
            ? FailureType.sessionExpired
            : error.statusCode == 403
            ? FailureType.insufficientPermissions
            : FailureType.network,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible actualizar tu presencia.',
        type: FailureType.network,
      );
    }
  }
}
