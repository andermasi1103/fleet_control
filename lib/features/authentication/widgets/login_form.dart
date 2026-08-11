import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/login_provider.dart';
import '../providers/session_provider.dart';
import '../models/user_session.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usuarioController;
  late TextEditingController _contrasenaController;
  late FocusNode _usuarioFocus;
  late FocusNode _contrasenaFocus;

  @override
  void initState() {
    super.initState();
    _usuarioController = TextEditingController();
    _contrasenaController = TextEditingController();
    _usuarioFocus = FocusNode();
    _contrasenaFocus = FocusNode();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    _usuarioFocus.dispose();
    _contrasenaFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    final state = ref.read(loginProvider);
    if (state.errorMessage != null) {
      ref.read(loginProvider.notifier).clearError();
    }
  }

  Future<void> _submit() async {
    final loginNotifier = ref.read(loginProvider.notifier);
    final loginState = ref.read(loginProvider);

    if (loginState.isLoading) return;

    if (_formKey.currentState?.validate() ?? false) {
      final result = await loginNotifier.login(
        username: _usuarioController.text.trim(),
        password: _contrasenaController.text,
      );

      if (!mounted) return;

      if (result.isSuccess && result.user != null) {
        // Guardar sesión
        ref.read(sessionProvider.notifier).setSession(
          UserSession(
            user: result.user!,
            loginAt: DateTime.now(),
          ),
        );

        // Navegar a /app → GoRouter decide destino según rol
        context.go('/app');
      }
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
            hint: 'Ingrese su usuario',
            prefixIcon: Icons.person,
            focusNode: _usuarioFocus,
            textInputAction: TextInputAction.next,
            autofocus: true,
            enabled: !loginState.isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El usuario es obligatorio';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_contrasenaFocus);
            },
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _contrasenaController,
            label: 'Contraseña',
            hint: 'Ingrese su contraseña',
            prefixIcon: Icons.lock,
            suffixIcon: IconButton(
              icon: Icon(
                loginState.obscurePassword
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: loginState.isLoading
                  ? null
                  : () {
                      ref.read(loginProvider.notifier)
                          .togglePasswordVisibility();
                    },
            ),
            focusNode: _contrasenaFocus,
            obscureText: loginState.obscurePassword,
            enabled: !loginState.isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'La contraseña es obligatoria';
              }
              if (value.length < 4) {
                return 'Debe tener al menos 4 caracteres';
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
}
