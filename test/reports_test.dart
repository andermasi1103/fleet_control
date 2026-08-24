import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_control/features/reports/data/reports_data_source.dart';

void main() {
  test('tipos de reportes tienen etiquetas estables', () {
    expect(ReportType.values, hasLength(6));
    expect(ReportType.orders.label, 'Pedidos');
    expect(ReportType.locations.value, 'locations');
  });

  test('resultado conserva el conteo para vista previa', () {
    const result = ReportResult(type: ReportType.orders, rows: [
      {'id': 'pedido-1'},
      {'id': 'pedido-2'},
    ]);
    expect(result.rows, hasLength(2));
  });
}
