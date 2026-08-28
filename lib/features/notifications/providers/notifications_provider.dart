import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/datasources/notifications_data_source.dart';
import '../data/dtos/notification_dto.dart';
import '../services/push_notification_service.dart';

final notificationsDataSourceProvider = Provider(
  (ref) => NotificationsDataSource(ref.watch(backendApiClientProvider)),
);
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(
    ref.watch(notificationsDataSourceProvider),
    ref.watch(appConfigProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

class NotificationsState {
  const NotificationsState({
    this.loading = false,
    this.notifications = const [],
    this.error,
  });
  final bool loading;
  final List<NotificationDto> notifications;
  final String? error;
  int get unreadCount => notifications.where((item) => !item.isRead).length;
  NotificationsState copyWith({
    bool? loading,
    List<NotificationDto>? notifications,
    String? error,
    bool clearError = false,
  }) => NotificationsState(
    loading: loading ?? this.loading,
    notifications: notifications ?? this.notifications,
    error: clearError ? null : error ?? this.error,
  );
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() => const NotificationsState();

  String? get _token {
    final session = ref.read(sessionProvider).session;
    return session == null || session.isExpired ? null : session.sessionToken;
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final notifications = await ref
          .read(notificationsDataSourceProvider)
          .list(token);
      state = state.copyWith(loading: false, notifications: notifications);
    } on Failure catch (error) {
      state = state.copyWith(loading: false, error: error.message);
    }
  }

  Future<void> markRead(NotificationDto notification) async {
    if (notification.isRead) return;
    final token = _token;
    if (token == null) return;
    try {
      await ref
          .read(notificationsDataSourceProvider)
          .markRead(token, notification.id);
      final now = DateTime.now();
      state = state.copyWith(
        notifications: [
          for (final item in state.notifications)
            if (item.id == notification.id)
              NotificationDto(
                id: item.id,
                type: item.type,
                title: item.title,
                message: item.message,
                entityType: item.entityType,
                entityId: item.entityId,
                route: item.route,
                isRead: true,
                createdAt: item.createdAt,
                readAt: now,
              )
            else
              item,
        ],
      );
    } on Failure catch (error) {
      state = state.copyWith(error: error.message);
    }
  }
}
