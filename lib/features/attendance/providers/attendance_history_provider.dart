import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/attendance_history_data_source.dart';
import '../data/dtos/location_dto.dart';
import 'attendance_history_state.dart';
import 'attendance_provider.dart' show attendanceDataSourceProvider;

final attendanceHistoryDataSourceProvider =
    Provider<AttendanceHistoryDataSource>((ref) {
      return AttendanceHistoryDataSource(ref.watch(supabaseClientProvider));
    });

final attendanceHistoryProvider =
    NotifierProvider<AttendanceHistoryNotifier, AttendanceHistoryState>(
      AttendanceHistoryNotifier.new,
    );

class AttendanceHistoryNotifier extends Notifier<AttendanceHistoryState> {
  static const _pageSize = 20;

  @override
  AttendanceHistoryState build() {
    final now = DateTime.now();
    return AttendanceHistoryState(from: _startOfDay(now), to: _endOfDay(now));
  }

  Future<void> load() => _load(replaceRecords: true);

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final token = _sessionToken();
    if (token == null) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(attendanceHistoryDataSourceProvider)
          .getHistory(
            sessionToken: token,
            from: state.from,
            to: state.to,
            localId: state.selectedLocalId,
            limit: _pageSize,
            offset: state.records.length,
          );
      final existingIds = state.records.map((record) => record.id).toSet();
      final additional = page.records
          .where((record) => existingIds.add(record.id))
          .toList(growable: false);
      final records = [...state.records, ...additional];
      state = state.copyWith(
        records: records,
        isLoadingMore: false,
        total: page.total,
        hasMore: records.length < page.total && page.records.isNotEmpty,
        clearError: true,
      );
    } on Failure catch (error) {
      _debugProviderError(error);
      state = state.copyWith(isLoadingMore: false, errorMessage: error.message);
    } catch (error) {
      _debugProviderError(error);
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'No fue posible cargar el historial de asistencia.',
      );
    }
  }

  Future<void> setPeriod(AttendanceHistoryPeriod period) async {
    if (period == AttendanceHistoryPeriod.custom) return;
    final now = DateTime.now();
    final range = switch (period) {
      AttendanceHistoryPeriod.today => (_startOfDay(now), _endOfDay(now)),
      AttendanceHistoryPeriod.week => (_startOfWeek(now), _endOfDay(now)),
      AttendanceHistoryPeriod.month => (_startOfMonth(now), _endOfDay(now)),
      AttendanceHistoryPeriod.custom => throw StateError('Periodo inválido.'),
    };
    state = state.copyWith(from: range.$1, to: range.$2, period: period);
    await load();
  }

  Future<void> setDateRange(DateTime from, DateTime to) async {
    state = state.copyWith(
      from: _startOfDay(from),
      to: _endOfDay(to),
      period: AttendanceHistoryPeriod.custom,
    );
    await load();
  }

  Future<void> setLocal(String? localId) async {
    state = localId == null
        ? state.copyWith(clearSelectedLocal: true)
        : state.copyWith(selectedLocalId: localId);
    await load();
  }

  Future<void> _load({required bool replaceRecords}) async {
    final token = _sessionToken();
    if (token == null) {
      state = state.copyWith(
        errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      final page = await ref
          .read(attendanceHistoryDataSourceProvider)
          .getHistory(
            sessionToken: token,
            from: state.from,
            to: state.to,
            localId: state.selectedLocalId,
            limit: _pageSize,
          );
      final locations = await _loadLocations(token);
      state = state.copyWith(
        records: replaceRecords ? page.records : state.records,
        locations: locations,
        isLoading: false,
        total: page.total,
        hasMore: page.records.length < page.total,
        clearError: true,
      );
    } on Failure catch (error) {
      _debugProviderError(error);
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      _debugProviderError(error);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar el historial de asistencia.',
      );
    }
  }

  Future<List<LocationDto>> _loadLocations(String token) async {
    if (state.locations.isNotEmpty) return state.locations;
    try {
      return await ref
          .read(attendanceDataSourceProvider)
          .getLocations(sessionToken: token);
    } on Failure {
      return state.locations;
    } catch (_) {
      return state.locations;
    }
  }

  String? _sessionToken() {
    final session = ref.read(sessionProvider).session;
    if (kDebugMode) {
      debugPrint(
        'attendance-history session: exists=${session != null}; '
        'expired=${session?.isExpired ?? false}; '
        'tokenEmpty=${session?.sessionToken.isEmpty ?? true}',
      );
    }
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      return null;
    }
    return session.sessionToken;
  }

  void _debugProviderError(Object error) {
    if (kDebugMode) {
      debugPrint(
        'attendance-history provider error: ${error.runtimeType}: $error',
      );
    }
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _endOfDay(DateTime value) => _startOfDay(
    value,
  ).add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

  static DateTime _startOfWeek(DateTime value) => _startOfDay(
    value.subtract(Duration(days: value.weekday - DateTime.monday)),
  );

  static DateTime _startOfMonth(DateTime value) =>
      DateTime(value.year, value.month);
}
