import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';

enum ReportType { orders, managements, attendance, drivers, vehicles, locations }

extension ReportTypeX on ReportType {
  String get value => name;
  String get label => switch (this) {
        ReportType.orders => 'Pedidos',
        ReportType.managements => 'Gestiones',
        ReportType.attendance => 'Asistencias',
        ReportType.drivers => 'Choferes',
        ReportType.vehicles => 'Vehículos',
        ReportType.locations => 'Locales',
      };
}

class ReportResult {
  const ReportResult({required this.type, required this.rows});
  final ReportType type;
  final List<Map<String, dynamic>> rows;
}

class ReportsDataSource {
  ReportsDataSource(this._client);
  final SupabaseClient _client;

  Future<ReportResult> load({
    required String token,
    required ReportType type,
    DateTime? from,
    DateTime? until,
    String? companyId,
    String? locationId,
    String? state,
    String? priority,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'reports-data',
        method: HttpMethod.get,
        headers: {'Authorization': 'Bearer $token'},
        queryParameters: {
          'type': type.value,
          if (from != null) 'desde': from.toUtc().toIso8601String(),
          if (until != null) 'hasta': until.toUtc().toIso8601String(),
          'empresa_id': ?companyId,
          'local_id': ?locationId,
          'estado': ?state,
          'prioridad': ?priority,
        },
      );
      final body = Map<String, dynamic>.from(response.data as Map);
      final rows = body['rows'];
      if (rows is! List) throw const FormatException();
      return ReportResult(
        type: type,
        rows: rows.map((row) => Map<String, dynamic>.from(row as Map)).toList(),
      );
    } on FunctionException catch (error) {
      final message = error.status == 422
          ? 'El reporte supera el límite permitido. Reduce el rango de fechas.'
          : error.status == 403
          ? 'No tienes permiso para generar reportes.'
          : 'No fue posible generar el reporte.';
      throw Failure(message: message, type: FailureType.supabase);
    } catch (_) {
      throw const Failure(message: 'No fue posible generar el reporte.', type: FailureType.supabase);
    }
  }
}
