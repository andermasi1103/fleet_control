import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/dtos/location_dto.dart';
import '../../providers/attendance_history_state.dart';

class AttendanceHistoryFilters extends StatelessWidget {
  const AttendanceHistoryFilters({
    super.key,
    required this.period,
    required this.from,
    required this.to,
    required this.locations,
    required this.selectedLocalId,
    required this.isLoading,
    required this.onPeriodSelected,
    required this.onLocalSelected,
  });

  final AttendanceHistoryPeriod period;
  final DateTime from;
  final DateTime to;
  final List<LocationDto> locations;
  final String? selectedLocalId;
  final bool isLoading;
  final ValueChanged<AttendanceHistoryPeriod> onPeriodSelected;
  final ValueChanged<String?> onLocalSelected;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<AttendanceHistoryPeriod>(
            key: ValueKey(period),
            initialValue: period,
            decoration: const InputDecoration(labelText: 'Período'),
            items: const [
              DropdownMenuItem(
                value: AttendanceHistoryPeriod.today,
                child: Text('Hoy'),
              ),
              DropdownMenuItem(
                value: AttendanceHistoryPeriod.week,
                child: Text('Esta semana'),
              ),
              DropdownMenuItem(
                value: AttendanceHistoryPeriod.month,
                child: Text('Este mes'),
              ),
              DropdownMenuItem(
                value: AttendanceHistoryPeriod.custom,
                child: Text('Personalizado'),
              ),
            ],
            onChanged: isLoading
                ? null
                : (value) {
                    if (value != null) onPeriodSelected(value);
                  },
          ),
          const SizedBox(height: 12),
          Text(
            period == AttendanceHistoryPeriod.custom
                ? '${_formatDate(from)} - ${_formatDate(to)}'
                : 'Desde ${_formatDate(from)} hasta ${_formatDate(to)}',
          ),
          if (locations.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedLocalId ?? ''),
              initialValue: selectedLocalId ?? '',
              decoration: const InputDecoration(labelText: 'Local'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Todos los locales'),
                ),
                ...locations.map(
                  (location) => DropdownMenuItem(
                    value: location.id,
                    child: Text(location.nombre),
                  ),
                ),
              ],
              onChanged: isLoading
                  ? null
                  : (value) => onLocalSelected(
                      value == null || value.isEmpty ? null : value,
                    ),
            ),
          ],
        ],
      ),
    ),
  );

  String _formatDate(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
}
