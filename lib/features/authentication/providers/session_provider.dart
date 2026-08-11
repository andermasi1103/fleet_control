import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_session.dart';
import 'session_state.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  void setSession(UserSession session) {
    state = state.copyWith(session: session);
  }

  void clearSession() {
    state = const SessionState();
  }

  void updateLastActivity() {
    if (state.session != null) {
      state = state.copyWith(
        session: state.session!.copyWith(
          lastActivity: DateTime.now(),
        ),
      );
    }
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
