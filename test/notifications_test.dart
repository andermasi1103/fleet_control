import 'package:fleet_control/app/app_router.dart';
import 'package:fleet_control/features/notifications/data/dtos/notification_dto.dart';
import 'package:fleet_control/features/notifications/providers/notifications_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsea una notificación de pedido nuevo', () {
    final notification = NotificationDto.fromJson({
      'id': 'notification-1',
      'tipo': 'new_order',
      'titulo': 'Nuevo pedido disponible',
      'mensaje': 'Local Centro lanzó un nuevo pedido.',
      'entity_type': 'order',
      'entity_id': 'order-1',
      'ruta': '/driver-orders',
      'leida': false,
      'created_at': '2026-08-24T12:00:00.000Z',
      'read_at': null,
    });

    expect(notification.route, '/driver-orders');
    expect(notification.isRead, isFalse);
  });

  test('el contador considera solamente notificaciones no leídas', () {
    final unread = NotificationDto.fromJson({
      'id': '1', 'tipo': 'new_order', 'titulo': 'Nuevo', 'mensaje': 'Pedido',
      'leida': false, 'created_at': '2026-08-24T12:00:00.000Z',
    });
    final read = NotificationDto.fromJson({
      'id': '2', 'tipo': 'new_order', 'titulo': 'Leído', 'mensaje': 'Pedido',
      'leida': true, 'created_at': '2026-08-24T11:00:00.000Z',
      'read_at': '2026-08-24T11:30:00.000Z',
    });
    expect(NotificationsState(notifications: [unread, read]).unreadCount, 1);
  });

  test('notificaciones es una utilidad sin permiso de vista específico', () {
    expect(requiredViewForPath('/notifications'), isNull);
    expect(requiredViewForPath('/driver-orders'), isNotNull);
  });
}
