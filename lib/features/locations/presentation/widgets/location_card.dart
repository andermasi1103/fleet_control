import 'package:flutter/material.dart';

import '../../../attendance/data/dtos/location_dto.dart';

class LocationCard extends StatelessWidget {
  const LocationCard({super.key, required this.location, required this.onEdit});

  final LocationDto location;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  location.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(location.isActive ? 'Activo' : 'Inactivo'),
                backgroundColor:
                    (location.isActive ? Colors.green : Colors.grey).withValues(
                      alpha: 0.15,
                    ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          if (location.empresaNombre != null) Text(location.empresaNombre!),
          if (location.direccion != null) ...[
            const SizedBox(height: 8),
            Text(location.direccion!),
          ],
          const SizedBox(height: 12),
          Text('Lat: ${location.latitud.toStringAsFixed(6)}'),
          Text('Lng: ${location.longitud.toStringAsFixed(6)}'),
          Text('Geocerca: ${location.radioMetros.round()} m'),
        ],
      ),
    ),
  );
}
