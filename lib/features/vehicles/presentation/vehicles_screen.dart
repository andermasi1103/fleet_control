import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/app_shell.dart';
import '../providers/vehicles_provider.dart';
import 'widgets/vehicle_card.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});
  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(vehiclesProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiclesProvider);
    final vehicles = state.filteredVehicles;
    return AppShell(
      title: 'Vehículos',
      showHomeAction: true,
      child: RefreshIndicator(
        onRefresh: () => ref.read(vehiclesProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehículos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Administra los vehículos registrados en MasiTrack.',
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final saved = await context.push<bool>(
                            '/vehicles/new',
                          );
                          if (saved == true && mounted) {
                            await ref.read(vehiclesProvider.notifier).refresh();
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('NUEVO VEHÍCULO'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              enabled: !state.isLoading,
              decoration: const InputDecoration(
                labelText: 'Buscar por patente, marca o modelo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: ref.read(vehiclesProvider.notifier).setSearchQuery,
            ),
            const SizedBox(height: 20),
            if (state.errorMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(state.errorMessage!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (state.isLoading && state.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage == null && state.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('No hay vehículos registrados.')),
              )
            else if (vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('No se encontraron vehículos.')),
              )
            else
              ...vehicles.map(
                (vehicle) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VehicleCard(
                    vehicle: vehicle,
                    onEdit: () async {
                      final saved = await context.push<bool>(
                        '/vehicles/${vehicle.id}/edit',
                        extra: vehicle,
                      );
                      if (saved == true && mounted) {
                        await ref.read(vehiclesProvider.notifier).refresh();
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
