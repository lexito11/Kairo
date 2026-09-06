import 'package:flutter/material.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/services/auth_service.dart';

Future<void> showChangePasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  final _prefs = PrefsService();

  bool _locked = false;
  bool _saving = false;
  bool _sendingMail = false;
  String? _error;
  String? _info;
  int _fails = 0;

  String? get _email => _auth.registeredEmail;

  @override
  void initState() {
    super.initState();
    _loadLock();
  }

  Future<void> _loadLock() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;
    final fails = await _prefs.getPasswordChangeFails(uid);
    final locked = fails >= PrefsService.passwordChangeMaxAttempts;
    if (!mounted) return;
    setState(() {
      _fails = fails;
      _locked = locked;
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
      filled: true,
      fillColor: KairoColors.darkBg,
      border: const OutlineInputBorder(borderSide: BorderSide.none),
    );
  }

  Future<void> _save() async {
    final email = _email;
    if (email == null) {
      setState(() => _error = 'No hay un correo registrado en KAIRO');
      return;
    }
    if (_locked) {
      setState(() => _error = 'Confirma tu identidad desde $email para cambiar la contraseña.');
      return;
    }
    final current = _current.text.trim();
    final next = _next.text.trim();
    final confirm = _confirm.text.trim();
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'La nueva contraseña y la confirmación no coinciden');
      return;
    }
    setState(() {
      _error = null;
      _info = null;
      _saving = true;
    });
    try {
      await _auth.changePasswordInApp(currentPassword: current, newPassword: next);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      await _loadLock();
      if (!mounted) return;
      setState(() => _error = AuthService.mapAuthError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendRecovery() async {
    final email = _email;
    if (email == null) {
      setState(() => _error = 'No hay un correo registrado en KAIRO');
      return;
    }
    setState(() {
      _error = null;
      _info = null;
      _sendingMail = true;
    });
    try {
      await _auth.sendPasswordRecoveryToRegisteredEmail();
      if (!mounted) return;
      setState(() {
        _info = 'Enviamos la confirmación solo a $email. Ábrela para cambiar la contraseña. Otro correo no sirve.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthService.mapAuthError(e));
    } finally {
      if (mounted) setState(() => _sendingMail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email ?? 'tu correo de KAIRO';
    final left = (PrefsService.passwordChangeMaxAttempts - _fails).clamp(0, 5);

    return AlertDialog(
      backgroundColor: KairoColors.darkCard,
      title: const Text('Cambiar contraseña', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: KairoColors.errorText, fontSize: 13, height: 1.35)),
              const SizedBox(height: 10),
            ],
            if (_info != null) ...[
              Text(_info!, style: const TextStyle(color: KairoColors.successText, fontSize: 13, height: 1.35)),
              const SizedBox(height: 10),
            ],
            if (_locked) ...[
              Text(
                'Agotaste los 5 intentos en la app. Debes confirmar tu identidad en $email. Si no entras desde ese correo, no podrás cambiar la contraseña.',
                style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13, height: 1.4),
              ),
            ] else ...[
              TextField(
                controller: _current,
                obscureText: false,
                autofillHints: const [],
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Contraseña actual'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _next,
                obscureText: false,
                autofillHints: const [],
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Nueva contraseña'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: false,
                autofillHints: const [],
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Confirmar contraseña'),
              ),
              if (_fails > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Intentos restantes: $left',
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ],
            const SizedBox(height: 14),
            TextButton(
              onPressed: _sendingMail ? null : _sendRecovery,
              child: Text(
                _sendingMail ? 'Enviando...' : 'No la recuerdo. Confirmar en $email',
                textAlign: TextAlign.left,
                style: const TextStyle(color: KairoColors.primary400, height: 1.3),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        if (!_locked)
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando...' : 'Guardar'),
          ),
      ],
    );
  }
}
