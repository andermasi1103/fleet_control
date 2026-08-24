import 'package:fleet_control/features/locations/presentation/widgets/location_map_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('propagates a map tap through onPointSelected', (tester) async {
    LatLng? selectedPoint;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 500,
            child: LocationMapPreview(
              latitude: -25.2637,
              longitude: -57.5759,
              radiusMeters: 150,
              onPointSelected: (point) => selectedPoint = point,
              tileProvider: _TransparentTileProvider(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 500));

    expect(selectedPoint, isNotNull);
  });
}

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}
