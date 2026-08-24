import 'package:flutter/material.dart';

import '../../../../shared/utils/vehicle_type.dart';
import '../../data/dtos/vehicle_dto.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onEdit});
  final VehicleDto vehicle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final model = [
      vehicle.brand,
      vehicle.model,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  vehicle.plate,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(label: Text(vehicle.isActive ? 'Activo' : 'Inactivo')),
              ],
            ),
            if (model.isNotEmpty) Text(model),
            Text('Tipo: ${vehicleTypeLabel(vehicle.vehicleType)}'),
            if (vehicle.year != null) Text('Año: ${vehicle.year}'),
            if (vehicle.companyName != null)
              Text('Empresa: ${vehicle.companyName}'),
            if (vehicle.description != null) ...[
              const SizedBox(height: 8),
              Text(vehicle.description!),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('EDITAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
