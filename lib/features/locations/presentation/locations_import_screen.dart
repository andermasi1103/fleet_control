import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/app_shell.dart';
import '../data/dtos/company_option_dto.dart';
import '../data/dtos/location_import_dto.dart';
import '../data/services/location_excel_service.dart';
import '../providers/locations_provider.dart';

class LocationsImportScreen extends ConsumerStatefulWidget {
  const LocationsImportScreen({super.key});

  @override
  ConsumerState<LocationsImportScreen> createState() =>
      _LocationsImportScreenState();
}

class _LocationsImportScreenState extends ConsumerState<LocationsImportScreen> {
  final _excelService = LocationExcelService();
  LocationImportPreview? _preview;
  String? _companyId;
  String? _fileName;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(locationsProvider).companies.isEmpty) {
        ref.read(locationsProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationsProvider);
    final companies = state.companies.where((company) => company.isActive).toList();
    if (_companyId == null && companies.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? setState(() => _companyId = companies.single.id) : null,
      );
    }
    final preview = _preview;
    final canConfirm = preview?.canImport == true &&
        _companyId != null &&
        !state.isSaving;

    return AppShell(
      title: 'Importar locales',
      showHomeAction: true,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Importar locales desde Excel',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Selecciona un archivo .xlsx de hasta 500 filas. La importación es atómica: si hay errores no se insertará ningún local.',
          ),
          const SizedBox(height: 24),
          _CompanySelector(
            companies: companies,
            selectedCompanyId: _companyId,
            enabled: !state.isSaving,
            onChanged: (value) => setState(() => _companyId = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: state.isSaving ? null : _downloadTemplate,
                icon: const Icon(Icons.download_outlined),
                label: const Text('DESCARGAR PLANTILLA'),
              ),
              FilledButton.icon(
                onPressed: state.isSaving ? null : _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('SELECCIONAR EXCEL'),
              ),
            ],
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text('Archivo: $_fileName'),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            _MessageCard(message: _message!, isError: true),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            _MessageCard(message: state.errorMessage!, isError: true),
          ],
          if (preview != null) ...[
            const SizedBox(height: 24),
            _PreviewCard(preview: preview),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: canConfirm ? _confirm : null,
                icon: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(state.isSaving ? 'IMPORTANDO...' : 'CONFIRMAR IMPORTACIÓN'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (!mounted || result == null) return;
    final file = result.files.single;
    if (file.bytes == null) {
      setState(() => _message = 'No se pudo leer el archivo seleccionado.');
      return;
    }
    setState(() {
      _fileName = file.name;
      _message = null;
      _preview = _excelService.parse(file.bytes!);
    });
  }

  Future<void> _downloadTemplate() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Descargar plantilla de locales',
        fileName: 'plantilla_locales.xlsx',
        bytes: _excelService.templateBytes(),
      );
      if (!mounted || path != null) return;
      setState(() => _message = 'No se pudo descargar la plantilla.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'No se pudo generar la plantilla Excel.');
      }
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (preview == null || !preview.canImport || _companyId == null) return;
    final imported = await ref.read(locationsProvider.notifier).importLocations(
          companyId: _companyId!,
          locations: preview.rows,
        );
    if (!mounted || imported == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$imported locales importados correctamente.')),
    );
    context.pop(true);
  }
}

class _CompanySelector extends StatelessWidget {
  const _CompanySelector({
    required this.companies,
    required this.selectedCompanyId,
    required this.enabled,
    required this.onChanged,
  });

  final List<CompanyOptionDto> companies;
  final String? selectedCompanyId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: selectedCompanyId,
        decoration: const InputDecoration(labelText: 'Empresa *'),
        items: companies
            .map((company) => DropdownMenuItem(
                  value: company.id,
                  child: Text(company.nombre),
                ))
            .toList(growable: false),
        onChanged: !enabled || companies.isEmpty ? null : onChanged,
        hint: companies.isEmpty ? const Text('No hay empresas disponibles') : null,
      );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final LocationImportPreview preview;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Previsualización', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Total filas: ${preview.total} · Válidas: ${preview.validCount} · Con error: ${preview.errorCount}'),
              if (preview.fileError != null) ...[
                const SizedBox(height: 8),
                Text(preview.fileError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fila')),
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Error')),
                  ],
                  rows: preview.rows
                      .map((row) => DataRow(cells: [
                            DataCell(Text('${row.rowNumber}')),
                            DataCell(Text(row.codigo)),
                            DataCell(Text(row.nombre)),
                            DataCell(Text(row.isValid ? 'Válida' : 'Con error')),
                            DataCell(SizedBox(width: 260, child: Text(row.error ?? '—'))),
                          ]))
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Card(
        color: isError ? Theme.of(context).colorScheme.errorContainer : null,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
      );
}
