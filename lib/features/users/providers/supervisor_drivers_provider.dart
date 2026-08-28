import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../authentication/providers/session_provider.dart';
import '../data/supervisor_drivers_data_source.dart';

final supervisorDriversDataSourceProvider = Provider(
  (ref) => SupervisorDriversDataSource(ref.watch(backendApiClientProvider)),
);
final supervisorDriversProvider =
    AutoDisposeNotifierProviderFamily<
      SupervisorDriversNotifier,
      SupervisorDriversDto?,
      String
    >(SupervisorDriversNotifier.new);

class SupervisorDriversNotifier
    extends AutoDisposeFamilyNotifier<SupervisorDriversDto?, String> {
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  @override
  SupervisorDriversDto? build(String arg) => null;
  Future<void> load() async {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired) {
      return;
    }
    isLoading = true;
    errorMessage = null;
    try {
      state = await ref
          .read(supervisorDriversDataSourceProvider)
          .load(session.sessionToken, arg);
    } catch (_) {
      errorMessage = 'No fue posible cargar los choferes asignados.';
    } finally {
      isLoading = false;
    }
  }

  void toggle(String id, bool selected) {
    final current = state;
    if (current == null) {
      return;
    }
    final ids = {...current.assignedIds};
    selected ? ids.add(id) : ids.remove(id);
    state = SupervisorDriversDto(drivers: current.drivers, assignedIds: ids);
  }

  Future<bool> save() async {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || state == null || isSaving) {
      return false;
    }
    isSaving = true;
    try {
      await ref
          .read(supervisorDriversDataSourceProvider)
          .save(session.sessionToken, arg, state!.assignedIds);
      return true;
    } catch (_) {
      errorMessage = 'No fue posible guardar los choferes asignados.';
      return false;
    } finally {
      isSaving = false;
    }
  }
}
