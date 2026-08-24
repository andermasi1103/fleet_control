import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/login_provider.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usuarioController;
  late final TextEditingController _passwordController;
  late final FocusNode _usuarioFocus;
  late final FocusNode _passwordFocus;

  @override
  void initState() {
    super.initState();
    _usuarioController = TextEditingController();
    _passwordController = TextEditingController();
    _usuarioFocus = FocusNode();
    _passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    _usuarioFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (ref.read(loginProvider).errorMessage != null) {
      ref.read(loginProvider.notifier).clearError();
    }
  }

  Future<void> _submit() async {
    final loginNotifier = ref.read(loginProvider.notifier);
    if (ref.read(loginProvider).isLoading ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final result = await loginNotifier.login(
      usuario: _usuarioController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted && result.isSuccess) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginProvider);
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppTextField(
            controller: _usuarioController,
            label: 'Usuario',
            hint: 'Ingresa tu usuario',
            prefixIcon: Icons.person_outline,
            focusNode: _usuarioFocus,
            textInputAction: TextInputAction.next,
            autofocus: true,
            enabled: !loginState.isLoading,
            validator: (value) {
              if ((value?.trim() ?? '').isEmpty) {
                return 'El usuario es obligatorio';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_passwordFocus);
            },
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _passwordController,
            label: 'Contraseña',
            hint: 'Ingresa tu contraseña',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                loginState.obscurePassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: loginState.isLoading
                  ? null
                  : ref.read(loginProvider.notifier).togglePasswordVisibility,
            ),
            focusNode: _passwordFocus,
            obscureText: loginState.obscurePassword,
            enabled: !loginState.isLoading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'La contraseña es obligatoria';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Iniciar sesión',
            onPressed: loginState.isLoading ? null : _submit,
            loading: loginState.isLoading,
            icon: Icons.login,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: loginState.isLoading
                ? null
                : () => _showPasswordHelp(context),
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
          if (loginState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loginState.errorMessage!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showPasswordHelp(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recuperación de contraseña'),
        content: const Text(
          'Solicita a tu supervisor el restablecimiento de tu contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }
}
