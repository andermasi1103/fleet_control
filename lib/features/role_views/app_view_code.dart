enum AppViewCode {
  home('home'),
  attendance('attendance'),
  companies('companies'),
  locations('locations'),
  users('users'),
  vehicles('vehicles'),
  orders('orders'),
  driverOrders('driver_orders'),
  managements('managements'),
  fleetMap('fleet_map'),
  settings('settings'),
  roleViewsManagement('role_views_management'),
  reports('reports');

  const AppViewCode(this.value);

  final String value;

  static AppViewCode? fromValue(String value) {
    for (final code in values) {
      if (code.value == value) return code;
    }
    return null;
  }

  static Set<AppViewCode> fromValues(Iterable<Object?> values) {
    return values
        .whereType<String>()
        .map(fromValue)
        .whereType<AppViewCode>()
        .toSet();
  }
}
