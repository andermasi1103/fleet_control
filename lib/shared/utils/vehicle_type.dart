import 'package:flutter/material.dart';

const vehicleTypes = ['moto', 'auto', 'camion', 'furgon', 'otro'];

String vehicleTypeLabel(String? type) {
  return switch (type) {
    'moto' => 'Moto',
    'auto' => 'Auto',
    'camion' => 'Camión',
    'furgon' => 'Furgón',
    'otro' => 'Otro',
    _ => 'Tipo no definido',
  };
}

IconData vehicleTypeIcon(String? type) {
  return switch (type) {
    'moto' => Icons.two_wheeler,
    'auto' => Icons.directions_car,
    'camion' => Icons.local_shipping,
    'furgon' => Icons.airport_shuttle,
    _ => Icons.person_pin_circle,
  };
}
