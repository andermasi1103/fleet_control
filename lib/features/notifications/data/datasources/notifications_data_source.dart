import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/notification_dto.dart';

class NotificationsDataSource {
  NotificationsDataSource(this._client);
  final ApiClient _client;

  Future<List<NotificationDto>> list(String sessionToken) async {
    final data = await _get('/api/notifications', sessionToken);
    final values = data['notifications'];
    if (values is! List) throw const FormatException('Respuesta inválida.');
    return values
        .map(
          (value) =>
              NotificationDto.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
  }

  Future<void> markRead(String sessionToken, String notificationId) async {
    await _call('/api/notifications/$notificationId/read', sessionToken);
  }

  Future<void> registerDevice(
    String sessionToken, {
    required String token,
    required String platform,
  }) => _call(
    '/api/notification-devices',
    sessionToken,
    body: {'token': token, 'platform': platform},
  );

  Future<void> unregisterDevice(String sessionToken, String token) => _call(
    '/api/notification-devices/unregister',
    sessionToken,
    body: {'token': token},
  );

  Future<Map<String, dynamic>> _get(String path, String token) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        path,
        bearerToken: token,
      );
      return _map(response.data);
    } on ApiException catch (error) {
      throw _failureFor(error);
    }
  }

  Future<Map<String, dynamic>> _call(
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        bearerToken: token,
        data: body,
      );
      return _map(response.data);
    } on ApiException catch (error) {
      throw _failureFor(error);
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure(
        message: 'No fue posible completar la operación.',
        type: FailureType.network,
      );
    }
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Respuesta inválida.');
  }

  Failure _failureFor(ApiException error) => Failure(
    message: error.statusCode == 401
        ? 'Tu sesión ha vencido. Inicia sesión nuevamente.'
        : 'No fue posible completar la operación.',
    statusCode: error.statusCode,
    type: error.statusCode == 401
        ? FailureType.sessionExpired
        : error.statusCode == 403
        ? FailureType.insufficientPermissions
        : FailureType.network,
  );
}
