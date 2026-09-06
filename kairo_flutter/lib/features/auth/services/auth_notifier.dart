import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _sub = AuthService().authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        AuthService.markPasswordRecovery();
      }
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  bool get isSignedIn => AuthService().isSignedIn;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
