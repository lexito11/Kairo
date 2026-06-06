import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isSignedIn => currentSession != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Inicio de sesión Email/Password (equivalente a NextAuth credentials)
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registro Email/Password + metadata (name, username) para el trigger SQL
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    String? name,
    String? username,
  }) async {
    final trimmedUsername = username?.trim();
    if (trimmedUsername != null && trimmedUsername.isNotEmpty) {
      final taken = await _isUsernameTaken(trimmedUsername);
      if (taken) {
        throw AuthException('Este usuario ya está en uso');
      }
    }

    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (trimmedUsername != null && trimmedUsername.isNotEmpty)
          'username': trimmedUsername,
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> _isUsernameTaken(String username) async {
    final rows = await _client
        .from('users')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return rows != null;
  }

  /// Mensaje amigable en español (como la web)
  static String mapAuthError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        return 'Email o contraseña incorrectos';
      }
      if (msg.contains('already registered') || msg.contains('already exists')) {
        return 'Este email ya está registrado';
      }
      if (msg.contains('password')) {
        return 'La contraseña debe tener al menos 6 caracteres';
      }
      return error.message;
    }
    return 'Error de autenticación. Por favor intenta de nuevo.';
  }
}
