import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/entities/auth_session.dart';
import '../domain/entities/authenticated_user.dart';

abstract interface class SessionStorage {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// Persiste exclusivamente la sesión ya autenticada en almacenamiento cifrado.
/// No almacena nunca la contraseña del usuario.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'fleet_control.auth_session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final serialized = await _storage.read(key: _sessionKey);
    if (serialized == null || serialized.isEmpty) return null;

    final value = jsonDecode(serialized);
    if (value is! Map) {
      throw const FormatException('Sesión almacenada inválida.');
    }

    return _sessionFromJson(Map<String, dynamic>.from(value));
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(_sessionToJson(session)),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);

  static Map<String, dynamic> _sessionToJson(AuthSession session) => {
    'sessionToken': session.sessionToken,
    'expiresAt': session.expiresAt.toUtc().toIso8601String(),
    'user': {
      'id': session.user.id,
      'empresaId': session.user.empresaId,
      'roleId': session.user.roleId,
      'role': session.user.role,
      'nombre': session.user.nombre,
      'usuario': session.user.usuario,
      'isActive': session.user.isActive,
    },
  };

  static AuthSession _sessionFromJson(Map<String, dynamic> json) {
    final token = json['sessionToken'];
    final expiresAt = json['expiresAt'];
    final user = json['user'];
    if (token is! String ||
        token.isEmpty ||
        expiresAt is! String ||
        user is! Map) {
      throw const FormatException('Sesión almacenada inválida.');
    }

    final parsedExpiry = DateTime.tryParse(expiresAt);
    final userJson = Map<String, dynamic>.from(user);
    final id = userJson['id'];
    final roleId = userJson['roleId'];
    final role = userJson['role'];
    final nombre = userJson['nombre'];
    final usuario = userJson['usuario'];
    final isActive = userJson['isActive'];
    final empresaId = userJson['empresaId'];
    if (parsedExpiry == null ||
        id is! String ||
        roleId is! String ||
        role is! String ||
        nombre is! String ||
        usuario is! String ||
        isActive is! bool ||
        (empresaId != null && empresaId is! String)) {
      throw const FormatException('Sesión almacenada inválida.');
    }

    return AuthSession(
      sessionToken: token,
      expiresAt: parsedExpiry,
      user: AuthenticatedUser(
        id: id,
        empresaId: empresaId as String?,
        roleId: roleId,
        role: role,
        nombre: nombre,
        usuario: usuario,
        isActive: isActive,
      ),
    );
  }
}
