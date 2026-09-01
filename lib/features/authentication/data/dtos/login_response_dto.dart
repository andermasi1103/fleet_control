import 'user_profile_dto.dart';

/// Respuesta privada del login de MasiTrack.
/// El token pertenece a la sesión, no al perfil del usuario.
class LoginResponseDto {
  const LoginResponseDto({
    required this.user,
    required this.sessionToken,
    required this.expiresAt,
  });

  final UserProfileDto user;
  final String sessionToken;
  final DateTime expiresAt;

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    final token =
        json['sessionToken']?.toString() ??
        json['session_token']?.toString() ??
        '';
    final expiresAtValue =
        json['expiresAt']?.toString() ?? json['expires_at']?.toString();
    final expiresAt = expiresAtValue == null
        ? null
        : DateTime.tryParse(expiresAtValue);
    final userValue = json['user'];

    if (token.isEmpty || expiresAt == null || userValue is! Map) {
      throw const FormatException('Respuesta de login inválida.');
    }

    final user = UserProfileDto.fromJson(Map<String, dynamic>.from(userValue));
    if (user.id.isEmpty || user.usuario.isEmpty || user.roleId.isEmpty) {
      throw const FormatException('Perfil de usuario inválido.');
    }

    return LoginResponseDto(
      user: user,
      sessionToken: token,
      expiresAt: expiresAt,
    );
  }
}
