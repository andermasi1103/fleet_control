import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../authentication/domain/entities/auth_session.dart';
import '../../authentication/providers/session_provider.dart';
import '../app_view_code.dart';
import '../data/datasources/role_views_data_source.dart';

final roleViewsDataSourceProvider = Provider<RoleViewsGateway>((ref) {
  return RoleViewsDataSource(ref.watch(backendApiClientProvider));
});

class CurrentUserViewsState {
  const CurrentUserViewsState({
    this.isLoading = false,
    this.views = const {},
    this.errorMessage,
  });

  final bool isLoading;
  final Set<AppViewCode> views;
  final String? errorMessage;

  bool get isReady => !isLoading && errorMessage == null;

  bool canView(AppViewCode code) => views.contains(code);
}

final currentUserViewsProvider =
    NotifierProvider<CurrentUserViewsNotifier, CurrentUserViewsState>(
      CurrentUserViewsNotifier.new,
    );

class CurrentUserViewsNotifier extends Notifier<CurrentUserViewsState> {
  String? _loadedToken;

  @override
  CurrentUserViewsState build() {
    ref.listen(sessionProvider, (_, next) {
      unawaited(_synchronize(next.session));
    });
    final currentSession = ref.read(sessionProvider).session;
    if (currentSession != null) {
      Future.microtask(() => _synchronize(currentSession));
    }
    return const CurrentUserViewsState();
  }

  Future<void> refresh() async {
    _loadedToken = null;
    await _synchronize(ref.read(sessionProvider).session);
  }

  Future<void> _synchronize(AuthSession? session) async {
    if (session == null || session.isExpired || session.sessionToken.isEmpty) {
      clear();
      return;
    }
    if (_loadedToken == session.sessionToken) return;

    final token = session.sessionToken;
    state = const CurrentUserViewsState(isLoading: true);
    try {
      final views = await ref
          .read(roleViewsDataSourceProvider)
          .getMyViews(sessionToken: token);
      if (ref.read(sessionProvider).session?.sessionToken != token) return;
      _loadedToken = token;
      state = CurrentUserViewsState(views: views);
    } on Failure catch (error) {
      if (ref.read(sessionProvider).session?.sessionToken != token) return;
      state = CurrentUserViewsState(errorMessage: error.message);
    } catch (_) {
      if (ref.read(sessionProvider).session?.sessionToken != token) return;
      state = const CurrentUserViewsState(
        errorMessage: 'No fue posible cargar las vistas disponibles.',
      );
    }
  }

  void clear() {
    _loadedToken = null;
    state = const CurrentUserViewsState();
  }
}
