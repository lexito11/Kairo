import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/kairo_alert.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
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
    final next = _next.text.trim();
    final confirm = _confirm.text.trim();
    if (next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Escribe y confirma la nueva contraseña');
      return;
    }
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
      context.go('/settings');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!allowed)
              const KairoAlert(
                message: 'Abre el enlace enviado al correo registrado en KAIRO. Otro correo no permite cambiar la contraseña.',
                type: KairoAlertType.error,
              )
            else ...[
              if (email != null)
                Text(
                  'Identidad confirmada para $email',
                  style: const TextStyle(color: KairoColors.darkTextSecondary, height: 1.35),
                ),
              const SizedBox(height: 16),
              if (_error != null) KairoAlert(message: _error!, type: KairoAlertType.error),
              TextField(
                controller: _next,
                obscureText: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Nueva contraseña',
                  hintStyle: TextStyle(color: KairoColors.darkTextSecondary),
                  filled: true,
                  fillColor: KairoColors.darkCard,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Confirmar contraseña',
                  hintStyle: TextStyle(color: KairoColors.darkTextSecondary),
                  filled: true,
                  fillColor: KairoColors.darkCard,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
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
    );
  }
}
