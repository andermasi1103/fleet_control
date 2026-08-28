class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.route,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String? entityType;
  final String? entityId;
  final String? route;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  factory NotificationDto.fromJson(Map<String, dynamic> json) => NotificationDto(
    id: json['id'] as String,
    type: json['tipo'] as String,
    title: json['titulo'] as String,
    message: json['mensaje'] as String,
    entityType: json['entity_type'] as String?,
    entityId: json['entity_id'] as String?,
    route: json['ruta'] as String?,
    isRead: json['leida'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
  );
}
