import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dtos/user_dto.dart';
import '../providers/users_provider.dart';

Future<void> showUserResetPasswordDialog(BuildContext context, UserDto user) {
  return showDialog<void>(
    context: context,
    builder: (context) => _UserResetPasswordDialog(user: user),
  );
}

class _UserResetPasswordDialog extends ConsumerStatefulWidget {
  const _UserResetPasswordDialog({required this.user});

  final UserDto user;

  @override
  ConsumerState<_UserResetPasswordDialog> createState() =>
      _UserResetPasswordDialogState();
}

class _UserResetPasswordDialogState
    extends ConsumerState<_UserResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(usersProvider).isResettingPassword;
    return AlertDialog(
      title: Text('Restablecer contraseña de ${widget.user.usuario}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !isSaving,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña *',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: isSaving
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: _passwordValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirmation,
              enabled: !isSaving,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña *',
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmation
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: isSaving
                      ? null
                      : () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: _confirmPasswordValidator,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: isSaving || _isSubmitting ? null : _submit,
          child: Text(isSaving ? 'GUARDANDO...' : 'RESTABLECER'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final success = await ref
        .read(usersProvider.notifier)
        .resetPassword(
          userId: widget.user.id,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      _passwordController.clear();
      _confirmController.clear();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña restablecida correctamente.')),
      );
      return;
    }
    final message =
        ref.read(usersProvider).errorMessage ??
        'No fue posible completar la operación.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (password.length > 1024) {
      return 'La contraseña no puede superar 1024 caracteres.';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final confirmation = value ?? '';
    if (confirmation.isEmpty) return 'Confirma la contraseña.';
    if (confirmation != _passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }
}
