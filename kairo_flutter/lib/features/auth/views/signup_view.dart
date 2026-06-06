import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/kairo_alert.dart';
import '../widgets/kairo_logo.dart';
import '../widgets/kairo_text_field.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _auth = AuthService();

  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await _auth.signUpWithPassword(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        username: _username.text.isEmpty ? null : _username.text,
      );
      if (!mounted) return;
      context.go('/auth/signin?registered=true');
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  const KairoLogo(),
                  const SizedBox(height: 16),
                  const Text(
                    'Crear Cuenta',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: KairoColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Únete a nuestra comunidad y comparte tu testimonio',
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
                          if (_error != null)
                            KairoAlert(message: _error!, type: KairoAlertType.error),
                          KairoTextField(
                            label: 'Nombre',
                            controller: _name,
                            hint: 'Tu nombre',
                            enabled: !_loading,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                          ),
                          const SizedBox(height: 16),
                          KairoTextField(
                            label: 'Usuario',
                            controller: _username,
                            hint: 'usuario123 (opcional)',
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 16),
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
                            hint: 'Mínimo 6 caracteres',
                            obscureText: true,
                            enabled: !_loading,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'La contraseña es requerida';
                              if (v.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          KairoTextField(
                            label: 'Confirmar Contraseña',
                            controller: _confirmPassword,
                            hint: 'Confirma tu contraseña',
                            obscureText: true,
                            enabled: !_loading,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Confirma tu contraseña' : null,
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: _loading ? 'Creando cuenta...' : 'Crear Cuenta',
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
                                  const TextSpan(text: '¿Ya tienes una cuenta? '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: _loading ? null : () => context.go('/auth/signin'),
                                      child: const Text(
                                        'Inicia sesión aquí',
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
