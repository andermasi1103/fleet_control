import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_control/features/attendance/data/dtos/location_dto.dart';
import 'package:fleet_control/features/fleet_tracking/data/dtos/fleet_driver_location_dto.dart';
import 'package:fleet_control/features/fleet_tracking/presentation/fleet_map_locations.dart';

void main() {
  const originLatitude = -25.2867;
  const originLongitude = -57.647;

  LocationDto location(String id, double latitude, double longitude) {
    return LocationDto(
      id: id,
      empresaId: 'company-a',
      nombre: 'Local $id',
      latitud: latitude,
      longitud: longitude,
      radioMetros: 100,
      isActive: true,
    );
  }

  FleetDriverLocationDto driver(
    String name,
    double? latitude,
    double? longitude,
  ) {
    return FleetDriverLocationDto(
      driverUserId: name,
      driverName: name,
      driverUsername: name,
      connectionStatus: 'online',
      operationalStatus: 'disponible',
      latitude: latitude,
      longitude: longitude,
    );
  }

  test('la distancia del mismo punto es aproximadamente cero', () {
    expect(
      geodesicDistanceMeters(
        fromLatitude: originLatitude,
        fromLongitude: originLongitude,
        toLatitude: originLatitude,
        toLongitude: originLongitude,
      ),
      closeTo(0, 0.01),
    );
  });

  test('calcula una distancia geodésica conocida dentro de tolerancia', () {
    final distance = geodesicDistanceMeters(
      fromLatitude: 0,
      fromLongitude: 0,
      toLatitude: 0,
      toLongitude: 1,
    );

    expect(distance, closeTo(111195, 500));
  });

  test('formatea metros y kilómetros de forma compacta', () {
    expect(distanceLabel(350), '350 m');
    expect(distanceLabel(1400), '1.4 km');
    expect(distanceLabel(null), 'Distancia no disponible');
  });

  test('omite coordenadas inválidas', () {
    expect(hasValidMapCoordinates(91, 0), isFalse);
    expect(hasValidMapCoordinates(0, double.infinity), isFalse);
    expect(
      geodesicDistanceMeters(
        fromLatitude: 91,
        fromLongitude: 0,
        toLatitude: 0,
        toLongitude: 0,
      ),
      isNull,
    );
  });

  test('ordena locales y devuelve el más cercano', () {
    final result = nearestLocationsForDriver(
      driver('Ana', originLatitude, originLongitude),
      [
        location('far', -25.4, -57.8),
        location('near', -25.2870, -57.6470),
        location('middle', -25.30, -57.68),
      ],
    );

    expect(result, hasLength(3));
    expect(result.first.value.id, 'near');
    expect(result.take(3).map((entry) => entry.value.id), [
      'near',
      'middle',
      'far',
    ]);
  });

  test('ordena choferes por cercanía al local', () {
    final result = nearestDriversForLocation(
      location('central', originLatitude, originLongitude),
      [
        driver('Lejos', -25.4, -57.8),
        driver('Cerca', -25.2870, -57.6470),
        driver('Sin GPS', null, null),
      ],
    );

    expect(result, hasLength(2));
    expect(result.first.value.driverName, 'Cerca');
  });

  test('el catálogo de iconos es cerrado y usa fallback seguro', () {
    expect(localMarkerIcon('store'), Icons.store);
    expect(localMarkerIcon('no-existe'), Icons.storefront);
  });

  test(
    'parsea color hexadecimal y conserva el fallback ante valor inválido',
    () {
      expect(
        localMarkerColor('#1565C0', Colors.black),
        const Color(0xFF1565C0),
      );
      expect(localMarkerColor('blue', Colors.black), Colors.black);
    },
  );

  test('los estilos de dos empresas pueden ser distintos', () {
    expect(localMarkerIcon('store'), isNot(localMarkerIcon('business')));
    expect(
      localMarkerColor('#E67E22', Colors.black),
      isNot(localMarkerColor('#2980B9', Colors.black)),
    );
  });
}
