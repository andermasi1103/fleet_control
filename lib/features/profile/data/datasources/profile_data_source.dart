import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';

class ProfileDataSource {
  ProfileDataSource(this._client);

  final SupabaseClient _client;

  Future<void> changePassword({
    required String sessionToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.functions.invoke(
        'profile-change-password',
        method: HttpMethod.post,
        headers: {'Authorization': 'Bearer $sessionToken'},
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on FunctionException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'profile-change-password failed: HTTP ${error.status}; '
          'code=${error.details is Map ? error.details['error'] : '-'}',
        );
      }
      throw Failure(
        message: _message(error.status),
        type: FailureType.supabase,
      );
    }
  }

  String _message(int status) {
    switch (status) {
      case 403:
        return 'La contraseña actual no es correcta.';
      case 401:
        return 'Tu sesión ha vencido. Inicia sesión nuevamente.';
      case 404:
        return 'No fue posible encontrar tu usuario.';
      case 400:
        return 'Revisa los datos ingresados.';
      default:
        return 'No fue posible cambiar la contraseña.';
    }
  }
}
