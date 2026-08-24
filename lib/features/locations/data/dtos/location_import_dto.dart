class LocationImportRow {
  const LocationImportRow({
    required this.rowNumber,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    required this.radioGeocercaMetros,
    required this.activo,
    this.error,
  });

  final int rowNumber;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String? direccion;
  final double? latitud;
  final double? longitud;
  final double? radioGeocercaMetros;
  final bool? activo;
  final String? error;

  bool get isValid => error == null;

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nombre': nombre,
        'descripcion': descripcion,
        'direccion': direccion,
        'latitud': latitud,
        'longitud': longitud,
        'radio_geocerca_metros': radioGeocercaMetros,
        'activo': activo,
      };

  LocationImportRow copyWith({String? error, bool clearError = false}) =>
      LocationImportRow(
        rowNumber: rowNumber,
        codigo: codigo,
        nombre: nombre,
        descripcion: descripcion,
        direccion: direccion,
        latitud: latitud,
        longitud: longitud,
        radioGeocercaMetros: radioGeocercaMetros,
        activo: activo,
        error: clearError ? null : error ?? this.error,
      );
}

class LocationImportPreview {
  const LocationImportPreview({
    required this.rows,
    required this.fileError,
  });

  final List<LocationImportRow> rows;
  final String? fileError;

  int get total => rows.length;
  int get validCount => rows.where((row) => row.isValid).length;
  int get errorCount => total - validCount + (fileError == null ? 0 : 1);
  bool get canImport => fileError == null && rows.isNotEmpty && errorCount == 0;
}
