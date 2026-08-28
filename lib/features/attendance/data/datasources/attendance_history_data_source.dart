import 'package:flutter/foundation.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../dtos/attendance_history_dto.dart';

class AttendanceHistoryDataSource {
  AttendanceHistoryDataSource(this._client);

  final ApiClient _client;

  Future<AttendanceHistoryPage> getHistory({
    required String sessionToken,
    DateTime? from,
    DateTime? to,
    String? localId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (limit < 1 ||
          limit > 100 ||
          offset < 0 ||
          (from != null && to != null && from.isAfter(to))) {
        throw const Failure(
          message: 'Los filtros seleccionados no son válidos.',
          type: FailureType.backend,
        );
      }
      final queryParameters = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (from != null) {
        queryParameters['desde'] = from.toUtc().toIso8601String();
      }
      if (to != null) {
        queryParameters['hasta'] = to.toUtc().toIso8601String();
      }
      final normalizedLocalId = localId?.trim();
      if (normalizedLocalId != null && normalizedLocalId.isNotEmpty) {
        queryParameters['local_id'] = normalizedLocalId;
      }
      _debugRequest(
        limit: limit,
        offset: offset,
        hasDesde: from != null,
        hasHasta: to != null,
        hasLocalId: normalizedLocalId?.isNotEmpty == true,
      );
      final response = await _client.get<Map<String, dynamic>>(
        '/api/attendance',
        bearerToken: sessionToken,
        queryParameters: queryParameters,
      );
      _debugResponse(response.statusCode ?? 200, response.data);
      final body = _map(response.data);
      final attendances = body['attendances'];
      if (attendances is! List) {
        throw const FormatException(
          'attendance-history invalid attendances list',
        );
      }
      final records = <AttendanceHistoryDto>[];
      for (var index = 0; index < attendances.length; index++) {
        try {
          records.add(AttendanceHistoryDto.fromJson(_map(attendances[index])));
        } on FormatException catch (error) {
          _debugParse('record[$index]: ${error.message}');
          rethrow;
        }
      }
      return AttendanceHistoryPage(
        records: records,
        limit: _integer('limit', body['limit'], allowZero: false),
        offset: _integer('offset', body['offset']),
        total: _integer('total', body['total']),
      );
    } on ApiException catch (error) {
      throw _failureFor(error.statusCode);
    } on Failure catch (error) {
      _debugParse('Failure: ${error.message}');
      rethrow;
    } on FormatException catch (error) {
      _debugParse('FormatException: ${error.message}');
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.backend,
      );
    } on TypeError catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.backend,
      );
    } on StateError catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.backend,
      );
    } on Exception catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.backend,
      );
    } catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.backend,
      );
    }
  }

  Failure _failureFor(int? status) {
    switch (status) {
      case 400:
        return const Failure(
          message: 'Los filtros seleccionados no son válidos.',
          type: FailureType.backend,
        );
      case 401:
        return const Failure(
          message: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
          type: FailureType.sessionExpired,
        );
      case 403:
        return const Failure(
          message: 'No tienes permiso para consultar este historial.',
          type: FailureType.insufficientPermissions,
        );
      case 404:
        return const Failure(
          message: 'El recurso solicitado ya no está disponible.',
          type: FailureType.backend,
        );
      default:
        return const Failure(
          message: 'No fue posible cargar el historial de asistencia.',
          type: FailureType.backend,
        );
    }
  }

  void _debugRequest({
    required int limit,
    required int offset,
    required bool hasDesde,
    required bool hasHasta,
    required bool hasLocalId,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'attendance-history request: limit=$limit; offset=$offset; '
      'hasDesde=$hasDesde; hasHasta=$hasHasta; hasLocalId=$hasLocalId',
    );
  }

  void _debugResponse(int status, Object? data) {
    if (!kDebugMode) return;
    final keys = data is Map
        ? data.keys.map((key) => key.toString()).join(',')
        : '-';
    debugPrint(
      'attendance-history response: status=$status; '
      'dataType=${data.runtimeType}; keys=$keys',
    );
  }

  void _debugParse(String message) {
    if (kDebugMode) debugPrint('attendance-history parse $message');
  }

  void _debugUnexpected(Object error) {
    if (kDebugMode) {
      debugPrint(
        'attendance-history unexpected error: '
        '${error.runtimeType}: $error',
      );
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map) {
      throw const FormatException('attendance-history invalid map response');
    }
    final map = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('attendance-history map key is not String');
      }
      map[entry.key as String] = entry.value;
    }
    return map;
  }

  int _integer(String field, Object? value, {bool allowZero = true}) {
    if (value is num &&
        value.isFinite &&
        value == value.roundToDouble() &&
        (allowZero ? value >= 0 : value > 0)) {
      return value.toInt();
    }
    throw FormatException('attendance-history invalid $field');
  }
}
