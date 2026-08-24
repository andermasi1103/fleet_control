import '../../../../core/errors/failure.dart';

abstract class TraccarAuthorizationProvider {
  /// Devuelve el valor completo del encabezado Authorization.
  /// La implementación debe obtenerlo de un backend o Edge Function seguro.
  Future<String> getAuthorizationHeader();
}

class MissingTraccarAuthorizationProvider
    implements TraccarAuthorizationProvider {
  const MissingTraccarAuthorizationProvider();

  @override
  Future<String> getAuthorizationHeader() {
    throw const Failure(
      message: 'La autorización segura de Traccar no está configurada.',
      type: FailureType.configuration,
    );
  }
}

/// Usa un valor inyectado en la configuración de la aplicación.
///
/// El valor debe ser el contenido completo del encabezado `Authorization`,
/// con su esquema incluido si Traccar lo requiere (por ejemplo, `Bearer ...`).
/// Para instalaciones donde el token no deba estar en el cliente, se puede
/// reemplazar este provider por uno que solicite un token efímero a un backend.
class ConfiguredTraccarAuthorizationProvider
    implements TraccarAuthorizationProvider {
  const ConfiguredTraccarAuthorizationProvider(this._authorization);

  final String _authorization;

  @override
  Future<String> getAuthorizationHeader() async {
    if (_authorization.trim().isEmpty) {
      throw const Failure(
        message: 'La autorización de Traccar no está configurada.',
        type: FailureType.configuration,
      );
    }

    return _authorization.trim();
  }
}
