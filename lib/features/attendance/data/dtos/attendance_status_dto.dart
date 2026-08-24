class AttendanceStatusDto {
  const AttendanceStatusDto({
    required this.nextAction,
    required this.hasOpenAttendance,
    this.lastAttendance,
  });

  final String nextAction;
  final bool hasOpenAttendance;
  final Map<String, dynamic>? lastAttendance;

  factory AttendanceStatusDto.fromJson(Map<String, dynamic> json) {
    final nextAction = json['next_action']?.toString();
    final hasOpenAttendance = json['has_open_attendance'];
    final lastAttendance = json['last_attendance'];

    if ((nextAction != 'entrada' && nextAction != 'salida') ||
        hasOpenAttendance is! bool ||
        (lastAttendance != null && lastAttendance is! Map)) {
      throw const FormatException('Estado de asistencia inválido.');
    }

    return AttendanceStatusDto(
      nextAction: nextAction!,
      hasOpenAttendance: hasOpenAttendance,
      lastAttendance: lastAttendance == null
          ? null
          : Map<String, dynamic>.from(lastAttendance),
    );
  }
}
