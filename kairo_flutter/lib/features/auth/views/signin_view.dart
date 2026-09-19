import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/kairo_alert.dart';
import '../widgets/kairo_logo.dart';
import '../widgets/kairo_text_field.dart';

class SignInView extends StatefulWidget {
  const SignInView({super.key, this.registeredSuccess = false});

  final bool registeredSuccess;

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  final _prefs = PrefsService();

  String? _error;
  bool _loading = false;
  bool _resending = false;
  bool _needsEmailConfirmation = false;
  bool _rememberLogin = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final saved = await _prefs.getRememberedEmail();
    if (!mounted || saved == null) return;
    setState(() {
      _rememberLogin = true;
      _email.text = saved;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _resendConfirmation() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Escribe un email válido para reenviar la confirmación');
      return;
    }
    setState(() {
      _error = null;
      _resending = true;
    });
    try {
      await _auth.resendSignupConfirmation(email);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te enviamos de nuevo el correo de confirmación')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthService.mapAuthError(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _needsEmailConfirmation = false;
      _loading = true;
    });
    try {
      await _auth.signInWithPassword(
        email: _email.text,
        password: _password.text,
      );
      if (_rememberLogin) {
        await _prefs.saveRememberedEmail(_email.text);
      } else {
        await _prefs.clearRememberedEmail();
      }
      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      final mapped = AuthService.mapAuthError(e);
      final raw = e.toString().toLowerCase();
      setState(() {
        _error = mapped;
        _needsEmailConfirmation = raw.contains('not confirmed') ||
            raw.contains('email not confirmed') ||
            raw.contains('confirm your email');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const KairoLogo(),
                  const SizedBox(height: 16),
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: KairoColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bienvenido de vuelta a nuestra comunidad',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: KairoColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: KairoColors.darkCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.registeredSuccess)
                            const KairoAlert(
                              message:
                                  'Cuenta creada exitosamente. Por favor inicia sesión.',
                              type: KairoAlertType.success,
                            ),
                          if (_error != null)
                            KairoAlert(message: _error!, type: KairoAlertType.error),
                          KairoTextField(
                            label: 'Email',
                            controller: _email,
                            hint: 'tu@email.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email, AutofillHints.username],
                            enabled: !_loading,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El email es requerido';
                              }
                              if (!v.contains('@')) return 'Email inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          KairoTextField(
                            label: 'Contraseña',
                            controller: _password,
                            hint: '••••••••',
                            obscureText: true,
                            showVisibilityToggle: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            enabled: !_loading,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'La contraseña es requerida' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => context.go('/auth/forgot-password'),
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: KairoColors.primary400,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _loading
                                ? null
                                : () => setState(() => _rememberLogin = !_rememberLogin),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberLogin,
                                      onChanged: _loading
                                          ? null
                                          : (v) => setState(() => _rememberLogin = v ?? false),
                                      activeColor: KairoColors.primary500,
                                      side: const BorderSide(color: KairoColors.darkTextSecondary),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Recordar mi correo en este dispositivo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: KairoColors.darkTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            label: _loading ? 'Iniciando sesión...' : 'Iniciar Sesión',
                            loading: _loading,
                            onPressed: _submit,
                          ),
                          if (_needsEmailConfirmation) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: (_loading || _resending) ? null : _resendConfirmation,
                              child: Text(
                                _resending ? 'Reenviando...' : 'Reenviar correo de confirmación',
                                style: const TextStyle(color: KairoColors.primary400),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: KairoColors.darkTextSecondary,
                                ),
                                children: [
                                  const TextSpan(text: '¿No tienes una cuenta? '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: _loading ? null : () => context.go('/auth/signup'),
                                      child: const Text(
                                        'Regístrate aquí',
                                        style: TextStyle(
                                          color: KairoColors.primary400,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _loading ? null : () => context.go('/'),
                    child: const Text(
                      '← Volver al inicio',
                      style: TextStyle(
                        fontSize: 14,
                        color: KairoColors.darkTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
