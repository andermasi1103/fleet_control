import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../dtos/location_import_dto.dart';

class LocationExcelService {
  static const headers = [
    'codigo',
    'nombre',
    'descripcion',
    'direccion',
    'latitud',
    'longitud',
    'radio_geocerca_metros',
    'activo',
  ];

  LocationImportPreview parse(Uint8List bytes) {
    try {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        return const LocationImportPreview(
          rows: [],
          fileError: 'El archivo no contiene hojas.',
        );
      }
      final sheet = workbook.tables.values
          .where((sheet) => sheet.rows.isNotEmpty)
          .firstOrNull;
      if (sheet == null) {
        return const LocationImportPreview(
          rows: [],
          fileError: 'El archivo está vacío.',
        );
      }
      final actualHeaders = sheet.rows.first
          .map((cell) => _text(cell?.value).toLowerCase())
          .toList(growable: false);
      final indexes = <String, int>{};
      for (final header in headers) {
        final index = actualHeaders.indexOf(header);
        if (index < 0) {
          return LocationImportPreview(
            rows: const [],
            fileError: 'Falta la columna obligatoria "$header".',
          );
        }
        indexes[header] = index;
      }

      final rows = <LocationImportRow>[];
      final seenCodes = <String>{};
      for (var index = 1; index < sheet.rows.length; index++) {
        final values = sheet.rows[index];
        if (values.every((cell) => _text(cell?.value).isEmpty)) continue;
        final row = _row(values, indexes, index + 1);
        final normalizedCode = row.codigo.toLowerCase();
        final duplicate =
            normalizedCode.isNotEmpty && !seenCodes.add(normalizedCode);
        rows.add(
          duplicate
              ? row.copyWith(
                  error: [
                    if (row.error != null) row.error!,
                    'Código duplicado dentro del archivo.',
                  ].join(' '),
                )
              : row,
        );
      }
      if (rows.length > 500) {
        return LocationImportPreview(
          rows: rows
              .map(
                (row) =>
                    row.copyWith(error: 'Máximo 500 filas por importación.'),
              )
              .toList(growable: false),
          fileError: 'El archivo supera el máximo de 500 filas.',
        );
      }
      return LocationImportPreview(rows: rows, fileError: null);
    } catch (_) {
      return const LocationImportPreview(
        rows: [],
        fileError: 'No se pudo leer el archivo .xlsx.',
      );
    }
  }

  Uint8List templateBytes() {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');
    final sheet = workbook['Locales'];
    sheet.appendRow(headers.map(TextCellValue.new).toList(growable: false));
    sheet.appendRow([
      TextCellValue('LOC-001'),
      TextCellValue('Sucursal Centro'),
      TextCellValue('Punto de retiro principal'),
      TextCellValue('Av. Principal 123'),
      TextCellValue('-25.300000'),
      TextCellValue('-57.600000'),
      TextCellValue('150'),
      TextCellValue('true'),
    ]);
    sheet.appendRow([
      TextCellValue('LOC-002'),
      TextCellValue('Sucursal Norte'),
      TextCellValue(''),
      TextCellValue('Ruta Norte 456'),
      TextCellValue('-25.280000'),
      TextCellValue('-57.580000'),
      TextCellValue('200'),
      TextCellValue('true'),
    ]);
    return Uint8List.fromList(workbook.encode() ?? const []);
  }

  LocationImportRow _row(
    List<Data?> values,
    Map<String, int> indexes,
    int rowNumber,
  ) {
    String value(String header) => _text(
      indexes[header]! < values.length ? values[indexes[header]!]?.value : null,
    );
    final codigo = value('codigo');
    final nombre = value('nombre');
    final latitud = _number(value('latitud'));
    final longitud = _number(value('longitud'));
    final radio = _number(value('radio_geocerca_metros'));
    final activo = _bool(value('activo'));
    final errors = <String>[
      if (codigo.isEmpty) 'Código vacío.',
      if (nombre.isEmpty) 'Nombre vacío.',
      if (latitud == null || latitud < -90 || latitud > 90) 'Latitud inválida.',
      if (longitud == null || longitud < -180 || longitud > 180)
        'Longitud inválida.',
      if (radio == null || radio < 10 || radio > 5000)
        'Radio inválido (10 a 5000 m).',
      if (activo == null) 'Activo debe ser true/false.',
    ];
    return LocationImportRow(
      rowNumber: rowNumber,
      codigo: codigo,
      nombre: nombre,
      descripcion: _nullIfEmpty(value('descripcion')),
      direccion: _nullIfEmpty(value('direccion')),
      latitud: latitud,
      longitud: longitud,
      radioGeocercaMetros: radio,
      activo: activo,
      error: errors.isEmpty ? null : errors.join(' '),
    );
  }

  static String _text(CellValue? value) => value?.toString().trim() ?? '';
  static String? _nullIfEmpty(String value) => value.isEmpty ? null : value;
  static double? _number(String value) =>
      double.tryParse(value.replaceAll(',', '.'));
  static bool? _bool(String value) => switch (value.toLowerCase()) {
    'true' || 'verdadero' || 'si' || 'sí' || '1' => true,
    'false' || 'falso' || 'no' || '0' => false,
    _ => null,
  };
}
