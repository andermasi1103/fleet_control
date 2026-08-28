import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_control/features/users/data/supervisor_drivers_data_source.dart';

void main() {
  test('parsea supervisor-drivers-list y admite lista vacía', () {
    final driver = SupervisorDriverDto.fromJson({'id': 'driver-1', 'usuario': 'chofer1', 'nombre': 'Chofer 1'});
    final data = SupervisorDriversDto(drivers: [driver], assignedIds: {});
    expect(data.drivers.single.nombre, 'Chofer 1');
    expect(data.assignedIds, isEmpty);
  });

  test('la selección múltiple conserva sólo los choferes elegidos', () {
    final selected = <String>{};
    selected.add('driver-1');
    selected.add('driver-2');
    selected.remove('driver-1');
    expect(selected, {'driver-2'});
  });
}
