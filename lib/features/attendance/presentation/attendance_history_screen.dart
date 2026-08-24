import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/app_shell.dart';
import '../providers/attendance_history_provider.dart';
import '../providers/attendance_history_state.dart';
import 'widgets/attendance_history_card.dart';
import 'widgets/attendance_history_filters.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  var _filterRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceHistoryProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceHistoryProvider);
    final notifier = ref.read(attendanceHistoryProvider.notifier);

    return AppShell(
      title: 'Historial de asistencia',
      showHomeAction: true,
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de asistencia',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text('Consulta tus registros de entrada y salida.'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refrescar',
                  onPressed: state.isLoading ? null : notifier.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AttendanceHistoryFilters(
              key: ValueKey('${state.period}:$_filterRevision'),
              period: state.period,
              from: state.from,
              to: state.to,
              locations: state.locations,
              selectedLocalId: state.selectedLocalId,
              isLoading: state.isLoading || state.isLoadingMore,
              onPeriodSelected: (period) => _selectPeriod(period, state),
              onLocalSelected: notifier.setLocal,
            ),
            const SizedBox(height: 20),
            if (state.errorMessage != null) ...[
              _ErrorMessage(message: state.errorMessage!),
              const SizedBox(height: 16),
            ],
            if (state.isLoading && state.records.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.records.isEmpty && state.errorMessage == null)
              const _EmptyHistory()
            else ...[
              ...state.records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AttendanceHistoryCard(record: record),
                ),
              ),
              if (state.hasMore) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.isLoadingMore ? null : notifier.loadMore,
                  icon: state.isLoadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(
                    state.isLoadingMore ? 'CARGANDO...' : 'CARGAR MÁS',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectPeriod(
    AttendanceHistoryPeriod period,
    AttendanceHistoryState state,
  ) async {
    if (period != AttendanceHistoryPeriod.custom) {
      await ref.read(attendanceHistoryProvider.notifier).setPeriod(period);
      return;
    }
    final firstDate = _dateOnly(DateTime(2020));
    final lastDate = _dateOnly(DateTime.now());
    final start = _clampDate(_dateOnly(state.from), firstDate, lastDate);
    final end = _clampDate(_dateOnly(state.to), firstDate, lastDate);
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: start.isAfter(end) ? end : start,
        end: end,
      ),
    );
    if (range == null || !mounted) {
      if (mounted) setState(() => _filterRevision++);
      return;
    }
    await ref
        .read(attendanceHistoryProvider.notifier)
        .setDateRange(range.start, range.end);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
    if (value.isBefore(first)) return first;
    if (value.isAfter(last)) return last;
    return value;
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 40),
    child: Center(
      child: Text(
        'No hay registros de asistencia para el período seleccionado.',
        textAlign: TextAlign.center,
      ),
    ),
  );
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
