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
    try {
      final rows = await _client
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      return rows != null;
    } on PostgrestException {
      // Si falla la consulta (red/RLS), no bloquear el registro por esto.
      return false;
    }
  }

  /// Mensaje amigable en español (como la web)
  static String mapAuthError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('failed to fetch') ||
        raw.contains('clientexception') ||
        raw.contains('socketexception') ||
        raw.contains('network')) {
      return 'No se pudo conectar con Supabase. Revisa:\n'
          '• Tu conexión a internet\n'
          '• Las credenciales en supabase_config.dart (URL y anon key)\n'
          '• En Supabase → Authentication → URL Configuration, agrega http://localhost:PUERTO';
    }
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login') ||
          msg.contains('invalid credentials') ||
          msg.contains('invalid email or password')) {
        return 'Email o contraseña incorrectos';
      }
      if (msg.contains('email not confirmed') ||
          msg.contains('not confirmed') ||
          msg.contains('confirm your email')) {
        return 'Debes confirmar tu email antes de iniciar sesión. Revisa tu bandeja de entrada.';
      }
      if (msg.contains('already registered') ||
          msg.contains('already exists') ||
          msg.contains('already been registered')) {
        return 'Este email ya está registrado';
      }
      if (msg.contains('password') &&
          (msg.contains('least') ||
              msg.contains('short') ||
              msg.contains('weak') ||
              msg.contains('6'))) {
        return 'La contraseña debe tener al menos 6 caracteres';
      }
      return error.message;
    }
    if (error is PostgrestException) {
      return 'No se pudo conectar con el servidor. Revisa tu internet o la configuración de Supabase.';
    }
    return 'Error de autenticación. Por favor intenta de nuevo.';
  }
}
