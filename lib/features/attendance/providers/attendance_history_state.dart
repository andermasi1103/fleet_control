import '../data/dtos/attendance_history_dto.dart';
import '../data/dtos/location_dto.dart';

enum AttendanceHistoryPeriod { today, week, month, custom }

class AttendanceHistoryState {
  const AttendanceHistoryState({
    required this.from,
    required this.to,
    this.period = AttendanceHistoryPeriod.today,
    this.records = const [],
    this.locations = const [],
    this.selectedLocalId,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.total = 0,
    this.errorMessage,
  });

  final DateTime from;
  final DateTime to;
  final AttendanceHistoryPeriod period;
  final List<AttendanceHistoryDto> records;
  final List<LocationDto> locations;
  final String? selectedLocalId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int total;
  final String? errorMessage;

  AttendanceHistoryState copyWith({
    DateTime? from,
    DateTime? to,
    AttendanceHistoryPeriod? period,
    List<AttendanceHistoryDto>? records,
    List<LocationDto>? locations,
    String? selectedLocalId,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    String? errorMessage,
    bool clearError = false,
    bool clearSelectedLocal = false,
  }) {
    return AttendanceHistoryState(
      from: from ?? this.from,
      to: to ?? this.to,
      period: period ?? this.period,
      records: records ?? this.records,
      locations: locations ?? this.locations,
      selectedLocalId: clearSelectedLocal
          ? null
          : selectedLocalId ?? this.selectedLocalId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
