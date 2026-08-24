import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../attendance/data/dtos/location_dto.dart';
import '../../dashboard/app_shell.dart';
import '../../authentication/providers/session_provider.dart';
import '../providers/locations_provider.dart';
import 'widgets/location_card.dart';

class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationsProvider);
    final role = ref.watch(sessionProvider).session?.user.role;
    final canImport = role == 'super_admin' || role == 'admin';

    return AppShell(
      title: 'Locales',
      showHomeAction: true,
      child: RefreshIndicator(
        onRefresh: () => ref.read(locationsProvider.notifier).load(),
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Text(
                    'Administrar locales',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (canImport)
                        OutlinedButton.icon(
                          onPressed: state.isLoading ? null : _importLocations,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('IMPORTAR EXCEL'),
                        ),
                      ElevatedButton.icon(
                        onPressed: state.isLoading ? null : _createLocation,
                        icon: const Icon(Icons.add),
                        label: const Text('NUEVO LOCAL'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (state.errorMessage != null) ...[
                _MessageCard(message: state.errorMessage!, isError: true),
                const SizedBox(height: 16),
              ],
              if (state.isLoading && state.locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.locations.isEmpty && state.errorMessage == null)
                const _EmptyLocations()
              else
                _LocationsGrid(
                  locations: state.locations,
                  columnCount: constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 680
                      ? 2
                      : 1,
                  onEdit: _editLocation,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createLocation() async {
    final saved = await context.push<bool>('/locations/new');
    if (saved == true && mounted) {
      await _reloadAndNotify('Local creado correctamente.');
    }
  }

  Future<void> _editLocation(LocationDto location) async {
    final saved = await context.push<bool>(
      '/locations/${location.id}/edit',
      extra: location,
    );
    if (saved == true && mounted) {
      await _reloadAndNotify('Local actualizado correctamente.');
    }
  }

  Future<void> _importLocations() async {
    final imported = await context.push<bool>('/locations/import');
    if (imported == true && mounted) {
      await _reloadAndNotify('Locales importados correctamente.');
    }
  }

  Future<void> _reloadAndNotify(String message) async {
    await ref.read(locationsProvider.notifier).load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LocationsGrid extends StatelessWidget {
  const _LocationsGrid({
    required this.locations,
    required this.columnCount,
    required this.onEdit,
  });

  final List<LocationDto> locations;
  final int columnCount;
  final ValueChanged<LocationDto> onEdit;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: locations.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columnCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      mainAxisExtent: 230,
    ),
    itemBuilder: (context, index) {
      final location = locations[index];
      return LocationCard(location: location, onEdit: () => onEdit(location));
    },
  );
}

class _EmptyLocations extends StatelessWidget {
  const _EmptyLocations();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 48),
    child: Center(
      child: Text('No hay locales registrados.', textAlign: TextAlign.center),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Card(
    color: isError ? Theme.of(context).colorScheme.errorContainer : null,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}
