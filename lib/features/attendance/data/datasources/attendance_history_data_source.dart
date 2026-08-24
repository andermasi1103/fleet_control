import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../dtos/attendance_history_dto.dart';

class AttendanceHistoryDataSource {
  AttendanceHistoryDataSource(this._client);

  final SupabaseClient _client;

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
          type: FailureType.supabase,
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
      final response = await _client.functions.invoke(
        'attendance-history',
        method: HttpMethod.get,
        headers: {'Authorization': 'Bearer $sessionToken'},
        queryParameters: queryParameters,
      );
      _debugResponse(response.status, response.data);
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
    } on FunctionException catch (error) {
      _debugFunctionError(error);
      throw _failureFor(error.status);
    } on Failure catch (error) {
      _debugParse('Failure: ${error.message}');
      rethrow;
    } on FormatException catch (error) {
      _debugParse('FormatException: ${error.message}');
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.supabase,
      );
    } on TypeError catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.supabase,
      );
    } on StateError catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.supabase,
      );
    } on Exception catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.supabase,
      );
    } catch (error) {
      _debugUnexpected(error);
      throw const Failure(
        message: 'No fue posible cargar el historial de asistencia.',
        type: FailureType.supabase,
      );
    }
  }

  Failure _failureFor(int status) {
    switch (status) {
      case 400:
        return const Failure(
          message: 'Los filtros seleccionados no son válidos.',
          type: FailureType.supabase,
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
          type: FailureType.supabase,
        );
      default:
        return const Failure(
          message: 'No fue posible cargar el historial de asistencia.',
          type: FailureType.supabase,
        );
    }
  }

  void _debugFunctionError(FunctionException error) {
    if (!kDebugMode) return;
    final details = error.details;
    final code = details is Map ? details['error']?.toString() : null;
    final response = details is Map
        ? 'map keys: ${details.keys.map((key) => key.toString()).join(', ')}'
        : details == null
        ? 'empty'
        : details.runtimeType.toString();
    debugPrint(
      'attendance-history failed: HTTP ${error.status}; '
      'code=${code ?? '-'}; response=$response',
    );
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
