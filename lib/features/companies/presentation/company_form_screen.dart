import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/app_shell.dart';
import '../data/dtos/company_dto.dart';
import '../providers/companies_provider.dart';

class CompanyFormScreen extends ConsumerStatefulWidget {
  const CompanyFormScreen({super.key, this.initialCompany});

  final CompanyDto? initialCompany;

  @override
  ConsumerState<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends ConsumerState<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;

  bool get _isEditing => widget.initialCompany != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialCompany?.nombre ?? '',
    );
    _isActive = widget.initialCompany?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companiesProvider);

    return AppShell(
      title: _isEditing ? 'Editar empresa' : 'Nueva empresa',
      showHomeAction: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEditing ? 'Editar empresa' : 'Registrar nueva empresa',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (state.errorMessage != null) ...[
                    _ErrorMessage(message: state.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    enabled: !state.isSaving,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa el nombre de la empresa.'
                        : null,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Empresa activa'),
                      value: _isActive,
                      onChanged: state.isSaving
                          ? null
                          : (value) => setState(() => _isActive = value),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: state.isSaving ? null : () => context.pop(),
                        child: const Text('CANCELAR'),
                      ),
                      ElevatedButton(
                        onPressed: state.isSaving ? null : _save,
                        child: Text(
                          state.isSaving ? 'GUARDANDO...' : 'GUARDAR',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(companiesProvider.notifier);
    final success = _isEditing
        ? await notifier.updateCompany(
            id: widget.initialCompany!.id,
            nombre: _nameController.text.trim(),
            isActive: _isActive,
          )
        : await notifier.createCompany(nombre: _nameController.text.trim());
    if (!mounted) return;
    if (success) {
      context.pop(true);
      return;
    }
    final message =
        ref.read(companiesProvider).errorMessage ??
        'No fue posible completar la operación.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}
