import 'dart:developer' as developer;

/// Script legado deshabilitado.
///
/// La autenticación se realiza exclusivamente mediante Supabase Auth. Este
/// proyecto no consulta ni filtra tablas por contraseña desde el cliente.
void main() {
  developer.log(
    'Prueba de autenticación retirada: usa el flujo de Supabase Auth.',
    name: 'FleetControl',
  );
}
