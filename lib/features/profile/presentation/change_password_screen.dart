import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../authentication/providers/session_provider.dart';
import '../../dashboard/app_shell.dart';
import '../providers/profile_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _submissionMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(profileChangingProvider)) return;
    if (!_formKey.currentState!.validate()) return;

    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      setState(() {
        _submissionMessage = 'Tu sesión ha vencido. Inicia sesión nuevamente.';
      });
      return;
    }

    setState(() => _submissionMessage = null);
    ref.read(profileChangingProvider.notifier).state = true;

    try {
      await ref
          .read(profileDataSourceProvider)
          .changePassword(
            sessionToken: session.sessionToken,
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ref.read(sessionProvider.notifier).localSignOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña actualizada correctamente. Inicia sesión nuevamente.',
          ),
        ),
      );
      context.go('/login');
    } on Failure catch (error) {
      if (mounted) setState(() => _submissionMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _submissionMessage = 'No fue posible cambiar la contraseña.',
        );
      }
    } finally {
      ref.read(profileChangingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChanging = ref.watch(profileChangingProvider);

    return AppShell(
      title: 'Cambiar contraseña',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Cambia tu contraseña',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Por seguridad, cerrarás sesión al actualizarla.',
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        controller: _currentPasswordController,
                        label: 'Contraseña actual *',
                        prefixIcon: Icons.lock_outline,
                        obscureText: !_showCurrentPassword,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        suffixIcon: IconButton(
                          tooltip: _showCurrentPassword
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          icon: Icon(
                            _showCurrentPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _showCurrentPassword = !_showCurrentPassword,
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Ingresa tu contraseña actual.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _newPasswordController,
                        label: 'Nueva contraseña *',
                        prefixIcon: Icons.lock_outline,
                        obscureText: !_showNewPassword,
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        suffixIcon: IconButton(
                          tooltip: _showNewPassword
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          icon: Icon(
                            _showNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _showNewPassword = !_showNewPassword,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              value.length < 8) {
                            return 'La nueva contraseña debe tener al menos 8 caracteres.';
                          }
                          if (value.length > 1024) {
                            return 'La nueva contraseña no puede superar 1024 caracteres.';
                          }
                          if (value == _currentPasswordController.text) {
                            return 'La nueva contraseña debe ser diferente de la actual.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirmar nueva contraseña *',
                        prefixIcon: Icons.lock_outline,
                        obscureText: !_showConfirmPassword,
                        textInputAction: TextInputAction.done,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        suffixIcon: IconButton(
                          tooltip: _showConfirmPassword
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma la nueva contraseña.';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      if (_submissionMessage != null) ...[
                        const SizedBox(height: 16),
                        _FormMessage(message: _submissionMessage!),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'CAMBIAR CONTRASEÑA',
                        icon: Icons.lock_reset_outlined,
                        loading: isChanging,
                        onPressed: isChanging ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
