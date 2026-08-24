import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../authentication/providers/session_provider.dart';
import 'users_provider.dart';
import 'user_locations_state.dart';

final userLocationsProvider =
    NotifierProvider<UserLocationsNotifier, UserLocationsState>(
      UserLocationsNotifier.new,
    );

class UserLocationsNotifier extends Notifier<UserLocationsState> {
  @override
  UserLocationsState build() => const UserLocationsState();

  Future<void> load(String userId) async {
    final token = _sessionToken();
    if (token == null) return _sessionFailure();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final locations = await ref
          .read(usersDataSourceProvider)
          .getUserLocations(sessionToken: token, userId: userId);
      state = UserLocationsState(
        locations: locations,
        selectedLocationIds: locations
            .where((location) => location.isAssigned)
            .map((location) => location.id)
            .toSet(),
      );
    } on Failure catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No fue posible cargar los locales del usuario.',
      );
    }
  }

  void toggle(String locationId, bool selected) {
    if (state.isSaving) return;
    final ids = {...state.selectedLocationIds};
    if (selected) {
      ids.add(locationId);
    } else {
      ids.remove(locationId);
    }
    state = state.copyWith(selectedLocationIds: ids, clearError: true);
  }

  void selectAll() {
    if (state.isSaving) return;
    final ids = {...state.selectedLocationIds};
    for (final location in state.locations) {
      if (location.isActive) ids.add(location.id);
    }
    state = state.copyWith(selectedLocationIds: ids);
  }

  void clearAll() {
    if (state.isSaving) return;
    state = state.copyWith(selectedLocationIds: <String>{});
  }

  Future<bool> save(String userId) async {
    final token = _sessionToken();
    if (token == null) {
      _sessionFailure();
      return false;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref
          .read(usersDataSourceProvider)
          .updateUserLocations(
            sessionToken: token,
            userId: userId,
            locationIds: state.selectedLocationIds.toList(growable: false),
          );
      state = state.copyWith(isSaving: false);
      return true;
    } on Failure catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'No fue posible completar la operación.',
      );
      return false;
    }
  }

  void _sessionFailure() {
    state = state.copyWith(
      isLoading: false,
      isSaving: false,
      errorMessage: 'Tu sesión ha vencido. Inicia sesión nuevamente.',
    );
  }

  String? _sessionToken() {
    final session = ref.read(sessionProvider).session;
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      return null;
    }
    return session.sessionToken;
  }
}
