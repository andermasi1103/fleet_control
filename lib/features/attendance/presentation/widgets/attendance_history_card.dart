import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/dtos/attendance_history_dto.dart';

class AttendanceHistoryCard extends StatelessWidget {
  const AttendanceHistoryCard({super.key, required this.record});

  final AttendanceHistoryDto record;

  @override
  Widget build(BuildContext context) {
    final isEntry = record.tipo == 'entrada';
    final color = isEntry
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    final coordinatesAvailable =
        record.latitud != null && record.longitud != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEntry ? Icons.login_outlined : Icons.logout_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.localNombre ?? 'Local no disponible',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(isEntry ? 'ENTRADA' : 'SALIDA'),
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_formatDate(record.fechaHora)),
            const SizedBox(height: 8),
            _GeofenceStatus(value: record.dentroGeocerca),
            if (coordinatesAvailable) ...[
              const SizedBox(height: 8),
              _LocationDetails(record: record),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      DateFormat('dd/MM/yyyy · HH:mm').format(value.toLocal());
}

class _GeofenceStatus extends StatelessWidget {
  const _GeofenceStatus({required this.value});

  final bool? value;

  @override
  Widget build(BuildContext context) {
    final label = switch (value) {
      true => 'Dentro de geocerca',
      false => 'Fuera de geocerca',
      null => 'No disponible',
    };
    return Row(
      children: [
        Icon(
          value == true
              ? Icons.verified_outlined
              : value == false
              ? Icons.warning_amber_outlined
              : Icons.help_outline,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _LocationDetails extends StatelessWidget {
  const _LocationDetails({required this.record});

  final AttendanceHistoryDto record;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    title: const Text('Ubicación registrada'),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Lat: ${record.latitud!.toStringAsFixed(6)}\n'
          'Lng: ${record.longitud!.toStringAsFixed(6)}',
        ),
      ),
    ],
  );
}
