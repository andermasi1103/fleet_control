import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_control/features/locations/data/services/location_excel_service.dart';

void main() {
  final service = LocationExcelService();

  test('acepta una plantilla válida', () {
    final preview = service.parse(service.templateBytes());

    expect(preview.fileError, isNull);
    expect(preview.total, 2);
    expect(preview.validCount, 2);
    expect(preview.canImport, isTrue);
  });

  test('reporta encabezado faltante', () {
    final bytes = _workbook(['codigo', 'nombre']);

    final preview = service.parse(bytes);

    expect(preview.fileError, contains('latitud'));
    expect(preview.canImport, isFalse);
  });

  test('reporta coordenadas, radio y duplicado inválidos', () {
    final bytes = _workbook(LocationExcelService.headers, rows: [
      ['LOC-1', 'Uno', '', '', '-91', '-181', '9', 'true'],
      ['loc-1', 'Dos', '', '', '-25.3', '-57.6', '150', 'true'],
    ]);

    final preview = service.parse(bytes);

    expect(preview.errorCount, 2);
    expect(preview.rows.first.error, allOf(contains('Latitud'), contains('Longitud'), contains('Radio')));
    expect(preview.rows.last.error, contains('duplicado'));
  });

  test('rechaza más de 500 filas', () {
    final rows = List.generate(
      501,
      (index) => [
        'LOC-$index', 'Local $index', '', '', '-25.3', '-57.6', '150', 'true',
      ],
    );

    final preview = service.parse(_workbook(LocationExcelService.headers, rows: rows));

    expect(preview.fileError, contains('500'));
    expect(preview.canImport, isFalse);
  });
}

Uint8List _workbook(List<String> headers, {List<List<String>> rows = const []}) {
  final workbook = Excel.createExcel();
  final sheet = workbook['Locales'];
  sheet.appendRow(headers.map(TextCellValue.new).toList(growable: false));
  for (final row in rows) {
    sheet.appendRow(row.map(TextCellValue.new).toList(growable: false));
  }
  return Uint8List.fromList(workbook.encode()!);
}
