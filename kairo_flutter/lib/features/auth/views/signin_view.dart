import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await _auth.signInWithPassword(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      setState(() => _error = AuthService.mapAuthError(e));
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
                      border: Border.all(color: KairoColors.darkBorder),
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
                            enabled: !_loading,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'La contraseña es requerida' : null,
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: _loading ? 'Iniciando sesión...' : 'Iniciar Sesión',
                            loading: _loading,
                            onPressed: _submit,
                          ),
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
