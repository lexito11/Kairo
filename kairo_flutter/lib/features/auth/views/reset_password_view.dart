import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/kairo_alert.dart';
import '../widgets/kairo_text_field.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final next = _next.text;
    final confirm = _confirm.text;
    if (next != confirm) {
      setState(() => _error = 'La nueva contraseña y la confirmación no coinciden');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await _auth.changePasswordFromEmailRecovery(next);
      if (!mounted) return;
      context.go('/feed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      setState(() => _error = AuthService.mapAuthError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.registeredEmail;
    final allowed = AuthService.passwordRecoveryPending;
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        title: const Text('Nueva contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!allowed) ...[
                const KairoAlert(
                  message:
                      'Abre el enlace enviado al correo registrado en KAIRO. Si expiró, solicita uno nuevo.',
                  type: KairoAlertType.error,
                ),
                GradientButton(
                  label: 'Solicitar un enlace nuevo',
                  onPressed: () => context.go('/auth/forgot-password'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/auth/signin'),
                  child: const Text(
                    'Volver a iniciar sesión',
                    style: TextStyle(color: KairoColors.primary400),
                  ),
                ),
              ] else ...[
                if (email != null)
                  Text(
                    'Identidad confirmada para $email',
                    style: const TextStyle(color: KairoColors.darkTextSecondary, height: 1.35),
                  ),
                const SizedBox(height: 16),
                if (_error != null) KairoAlert(message: _error!, type: KairoAlertType.error),
                KairoTextField(
                  label: 'Nueva contraseña',
                  controller: _next,
                  hint: 'Mínimo 6 caracteres',
                  obscureText: true,
                  showVisibilityToggle: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !_saving,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Escribe la nueva contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                KairoTextField(
                  label: 'Confirmar contraseña',
                  controller: _confirm,
                  hint: 'Confirma tu contraseña',
                  obscureText: true,
                  showVisibilityToggle: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _save(),
                  enabled: !_saving,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Confirma la nueva contraseña' : null,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: _saving ? 'Guardando...' : 'Guardar contraseña',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
