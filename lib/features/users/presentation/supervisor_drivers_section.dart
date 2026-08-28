import 'package:flutter/material.dart';

import '../data/supervisor_drivers_data_source.dart';

class SupervisorDriversSection extends StatelessWidget {
  const SupervisorDriversSection({super.key, required this.data, required this.isSaving, required this.onChanged, required this.onSave, required this.onRetry});
  final SupervisorDriversDto? data;
  final bool isSaving;
  final void Function(String, bool) onChanged;
  final VoidCallback onSave;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('CHOFERES ASIGNADOS', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    if (data == null) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())) else ...[
      if (data!.drivers.isEmpty) const Text('No hay choferes activos disponibles para esta empresa.'),
      ...data!.drivers.map((driver) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: data!.assignedIds.contains(driver.id),
        onChanged: isSaving ? null : (selected) => onChanged(driver.id, selected ?? false),
        title: Text(driver.nombre), subtitle: Text(driver.usuario),
      )),
      Align(alignment: Alignment.centerRight, child: FilledButton(
        onPressed: isSaving ? null : onSave,
        child: Text(isSaving ? 'GUARDANDO...' : 'GUARDAR CHOFERES'),
      )),
    ],
  ])));
}
