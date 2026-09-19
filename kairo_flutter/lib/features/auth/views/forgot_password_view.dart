import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/kairo_alert.dart';
import '../widgets/kairo_logo.dart';
import '../widgets/kairo_text_field.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _auth = AuthService();

  String? _error;
  String? _info;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _info = null;
      _loading = true;
    });
    try {
      await _auth.sendPasswordRecoveryEmail(_email.text);
      if (!mounted) return;
      setState(() {
        _info =
            'Si ese correo está registrado en KAIRO, te enviamos un enlace para crear una nueva contraseña.';
      });
    } catch (e) {
      if (!mounted) return;
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
                    'Recuperar contraseña',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: KairoColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Te enviaremos un enlace al correo con el que te registraste.',
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
                          if (_error != null)
                            KairoAlert(message: _error!, type: KairoAlertType.error),
                          if (_info != null)
                            KairoAlert(message: _info!, type: KairoAlertType.success),
                          KairoTextField(
                            label: 'Email',
                            controller: _email,
                            hint: 'tu@email.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            onFieldSubmitted: (_) => _submit(),
                            enabled: !_loading,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El email es requerido';
                              }
                              if (!v.contains('@')) return 'Email inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: _loading ? 'Enviando...' : 'Enviar enlace',
                            loading: _loading,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: _loading ? null : () => context.go('/auth/signin'),
                              child: const Text(
                                'Volver a iniciar sesión',
                                style: TextStyle(
                                  color: KairoColors.primary400,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
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
