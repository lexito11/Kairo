import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _sub = AuthService().authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        AuthService.markPasswordRecovery();
      } else if (state.event == AuthChangeEvent.signedOut) {
        AuthService.clearPasswordRecovery();
        AuthService().accountBlocked = false;
        _statusChannel?.unsubscribe();
        _statusChannel = null;
      }
      notifyListeners();
      _refreshAccountStatus();
      _listenAccountStatus();
    });
    _refreshAccountStatus();
    _listenAccountStatus();
  }

  late final StreamSubscription<AuthState> _sub;
  RealtimeChannel? _statusChannel;

  bool get isSignedIn => AuthService().isSignedIn;
  bool get accountBlocked => AuthService().accountBlocked;

  Future<void> _refreshAccountStatus() async {
    if (!isSignedIn) return;
    final blocked = await AuthService().refreshAccountStatus();
    if (blocked) notifyListeners();
  }

  void _listenAccountStatus() {
    final uid = AuthService().currentUser?.id;
    _statusChannel?.unsubscribe();
    _statusChannel = null;
    if (uid == null) return;
    _statusChannel = Supabase.instance.client
        .channel('account-status:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (_) {
            _refreshAccountStatus();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _statusChannel?.unsubscribe();
    _sub.cancel();
    super.dispose();
  }
}
