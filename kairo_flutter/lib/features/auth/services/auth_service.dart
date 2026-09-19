import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/moderation/kairo_content_policy.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/utils/username.dart';

class AuthService {
  AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isSignedIn => currentSession != null;

  static bool passwordRecoveryPending = false;
  static void markPasswordRecovery() => passwordRecoveryPending = true;
  static void clearPasswordRecovery() => passwordRecoveryPending = false;

  String? get registeredEmail {
    final email = currentUser?.email?.trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Inicio de sesión Email/Password (equivalente a NextAuth credentials)
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await refreshAccountStatus();
    return response;
  }

  bool accountBlocked = false;

  Future<bool> refreshAccountStatus() async {
    final uid = currentUser?.id;
    if (uid == null) {
      accountBlocked = false;
      return false;
    }
    try {
      final row = await _client
          .from('users')
          .select('account_status')
          .eq('id', uid)
          .maybeSingle();
      accountBlocked = row?['account_status'] == 'blocked';
    } catch (_) {
      accountBlocked = false;
    }
    return accountBlocked;
  }

  /// Registro Email/Password + metadata (name, username) para el trigger SQL
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    String? name,
    String? username,
  }) async {
    final trimmedUsername = username == null || username.trim().isEmpty
        ? null
        : UsernamePolicy.sanitize(username);
    KairoContentPolicy.assertText(name);
    if (trimmedUsername != null) {
      KairoContentPolicy.assertText(trimmedUsername);
      final invalid = UsernamePolicy.validate(trimmedUsername);
      if (invalid != null) throw AuthException(invalid);
      if (await _isUsernameTaken(trimmedUsername)) {
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

  Future<void> signOut() async {
    clearPasswordRecovery();
    await _client.auth.signOut();
  }

  Future<void> sendPasswordRecoveryEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw AuthException('Email inválido');
    }
    await _client.auth.resetPasswordForEmail(
      trimmed,
      redirectTo: _recoveryRedirect(),
    );
  }

  Future<void> resendSignupConfirmation(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw AuthException('Email inválido');
    }
    await _client.auth.resend(type: OtpType.signup, email: trimmed);
  }

  Future<void> updatePassword(String newPassword) async {
    final trimmed = newPassword.trim();
    if (trimmed.length < 6) {
      throw AuthException('La contraseña debe tener al menos 6 caracteres');
    }
    await _client.auth.updateUser(UserAttributes(password: trimmed));
  }

  Future<bool> verifyCurrentPassword(String password) async {
    final email = registeredEmail;
    if (email == null) throw AuthException('No hay un correo registrado en KAIRO');
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException {
      return false;
    }
  }

  Future<void> changePasswordInApp({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uid = currentUser?.id;
    final email = registeredEmail;
    if (uid == null || email == null) {
      throw AuthException('Debes iniciar sesión con tu cuenta de KAIRO');
    }
    final prefs = PrefsService();
    if (await prefs.isPasswordChangeLocked(uid)) {
      throw AuthException(
        'Demasiados intentos. Confirma tu identidad desde el correo registrado: $email',
      );
    }
    final ok = await verifyCurrentPassword(currentPassword);
    if (!ok) {
      final fails = await prefs.addPasswordChangeFail(uid);
      final left = PrefsService.passwordChangeMaxAttempts - fails;
      if (left <= 0) {
        throw AuthException(
          'Agotaste los 5 intentos. Debes confirmar tu identidad en $email para cambiar la contraseña.',
        );
      }
      throw AuthException('Contraseña actual incorrecta. Te quedan $left intento${left == 1 ? '' : 's'}.');
    }
    await updatePassword(newPassword);
    await prefs.clearPasswordChangeFails(uid);
  }

  Future<void> changePasswordFromEmailRecovery(String newPassword) async {
    if (!passwordRecoveryPending) {
      throw AuthException('Debes abrir el enlace enviado al correo registrado en KAIRO.');
    }
    final uid = currentUser?.id;
    await updatePassword(newPassword);
    if (uid != null) await PrefsService().clearPasswordChangeFails(uid);
    clearPasswordRecovery();
  }

  Future<void> sendPasswordRecoveryToRegisteredEmail() async {
    final email = registeredEmail;
    if (email == null) throw AuthException('No hay un correo registrado en KAIRO');
    await sendPasswordRecoveryEmail(email);
  }

  static const nativeAuthCallback = 'io.kairo.app://login-callback/';

  static String _recoveryRedirect() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.startsWith('http')) {
        return '$origin/#/auth/reset-password';
      }
    }
    return nativeAuthCallback;
  }

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
    if (error is KairoAccountBlockedException) return error.toString();
    if (error is KairoContentBlockedException) return error.toString();
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
      if (msg.contains('account_blocked') || msg.contains('límite de infracciones')) {
        return KairoAccountBlockedException.userMessage;
      }
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
          msg.contains('already been registered') ||
          msg.contains('user already registered')) {
        return 'Este email ya está registrado';
      }
      if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      }
      if (msg.contains('expired') || msg.contains('otp_expired')) {
        return 'El enlace expiró. Solicita uno nuevo para cambiar la contraseña.';
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
