import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../../dashboard/app_shell.dart';
import '../data/report_export_service.dart';
import '../data/reports_data_source.dart';

final reportsDataSourceProvider = Provider((ref) => ReportsDataSource(ref.watch(backendApiClientProvider)));

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportType _type = ReportType.orders;
  DateTime? _from;
  DateTime? _until;
  ReportResult? _result;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final isSupervisor = ref.watch(sessionProvider).session?.user.role == 'supervisor';
    final reportTypes = isSupervisor
        ? ReportType.values.where((type) => type != ReportType.locations).toList()
        : ReportType.values;
    if (isSupervisor && _type == ReportType.locations) _type = ReportType.orders;
    return AppShell(
    title: 'Reportes', showHomeAction: true,
    child: ListView(padding: const EdgeInsets.all(24), children: [
      Text('Reportes', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: reportTypes.map((type) => ChoiceChip(
        label: Text(type.label), selected: _type == type,
        onSelected: _loading ? null : (_) => setState(() { _type = type; _result = null; _error = null; }),
      )).toList()),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 12, children: [
        OutlinedButton(onPressed: _loading ? null : () => _pickDate(true), child: Text(_from == null ? 'FECHA DESDE' : _from!.toLocal().toString().split(' ').first)),
        OutlinedButton(onPressed: _loading ? null : () => _pickDate(false), child: Text(_until == null ? 'FECHA HASTA' : _until!.toLocal().toString().split(' ').first)),
        FilledButton(onPressed: _loading ? null : _generate, child: Text(_loading ? 'GENERANDO...' : 'GENERAR')),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (_result != null) Padding(padding: const EdgeInsets.only(top: 24), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tipo: ${_result!.type.label}'), Text('Registros: ${_result!.rows.length}'),
        if (_result!.rows.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No hay datos para los filtros seleccionados.')),
        if (_result!.rows.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Wrap(spacing: 12, children: [
          FilledButton.icon(onPressed: () => _export(true), icon: const Icon(Icons.table_view), label: const Text('DESCARGAR EXCEL')),
          FilledButton.icon(onPressed: () => _export(false), icon: const Icon(Icons.picture_as_pdf), label: const Text('DESCARGAR PDF')),
        ])),
      ])))),
    ]),
  );
  }

  Future<void> _pickDate(bool from) async {
    final value = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (value != null && mounted) {
      setState(() { if (from) { _from = value; } else { _until = value; } });
    }
  }
  Future<void> _generate() async {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired) return;
    setState(() { _loading = true; _error = null; });
    try { final result = await ref.read(reportsDataSourceProvider).load(token: session.sessionToken, type: _type, from: _from, until: _until); if (mounted) setState(() => _result = result); }
    on Failure catch (error) { if (mounted) setState(() => _error = error.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _export(bool excel) async {
    final result = _result; if (result == null) return;
    final date = (_from ?? DateTime.now()).toIso8601String().substring(0, 10);
    final filename = '${result.type.value}_$date';
    try { final service = ReportExportService(); if (excel) { await service.excel(result, filename); } else { await service.pdf(result, filename); } }
    catch (_) { if (mounted) setState(() => _error = 'No fue posible descargar el archivo.'); }
  }
}
