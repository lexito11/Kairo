import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../events/services/churches_repository.dart';
import '../../users/services/users_repository.dart';
import '../widgets/change_password_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _users = UsersRepository();
  final _churches = ChurchesRepository();
  bool _saveStoryArchive = true;
  bool _archiveLoaded = false;
  bool _archiveSaving = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadArchivePref();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    if (!AuthService().isSignedIn) return;
    final admin = await _churches.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() => _isAdmin = admin);
  }

  Future<void> _loadArchivePref() async {
    if (!AuthService().isSignedIn) return;
    final value = await _users.getSaveStoryArchive();
    if (!mounted) return;
    setState(() {
      _saveStoryArchive = value;
      _archiveLoaded = true;
    });
  }

  Future<void> _setArchive(bool value) async {
    setState(() {
      _saveStoryArchive = value;
      _archiveSaving = true;
    });
    try {
      await _users.updateSaveStoryArchive(value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveStoryArchive = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar. Ejecuta la migración SQL del archivo de historias.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _archiveSaving = false);
    }
  }

  Future<void> _changePassword() => showChangePasswordDialog(context);

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: const Text('Acerca de KAIRO', style: TextStyle(color: Colors.white)),
        content: const Text(
          'KAIRO es una red social cristiana para compartir fe, oración, testimonios y la Biblia con la comunidad.\n\nVersión 1.0.0',
          style: TextStyle(color: KairoColors.darkTextSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final theme = context.watch<ThemeProvider>();
    final email = auth.currentUser?.email;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          const _SectionLabel('Tu cuenta'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Editar perfil',
            subtitle: 'Foto, nombre, usuario y biografía',
            onTap: () => context.push('/profile/edit'),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Cambiar contraseña',
            subtitle: email,
            onTap: _changePassword,
          ),
          const _SectionLabel('Cómo usas KAIRO'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            onTap: () => context.push('/notifications'),
          ),
          _SettingsTile(
            icon: Icons.people_outline,
            title: 'Personas',
            subtitle: 'Bloqueados, desbloquear o quitar de amigos',
            onTap: () => context.push('/settings/personas'),
          ),
          if (auth.isSignedIn && _archiveLoaded)
            SwitchListTile(
              title: const Text('Guardar historias'),
              subtitle: const Text(
                'Quedan en tu archivo después de 24 h para destacarlas en Momentos cuando quieras.',
              ),
              value: _saveStoryArchive,
              activeThumbColor: KairoColors.primary500,
              secondary: _archiveSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary500),
                    )
                  : const Icon(Icons.auto_stories_outlined),
              onChanged: _archiveSaving ? null : _setArchive,
            ),
          SwitchListTile(
            title: const Text('Tema oscuro'),
            subtitle: Text(theme.isDark ? 'Modo oscuro activo' : 'Modo claro activo'),
            value: theme.isDark,
            activeThumbColor: KairoColors.primary500,
            secondary: const Icon(Icons.dark_mode_outlined),
            onChanged: theme.toggle,
          ),
          if (_isAdmin) ...[
            const _SectionLabel('Administración'),
            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Moderación',
              subtitle: 'Reportes, infracciones y cuentas bloqueadas',
              onTap: () => context.push('/admin/moderation'),
            ),
            _SettingsTile(
              icon: Icons.church_outlined,
              title: 'Solicitudes de iglesias',
              onTap: () => context.push('/admin/churches'),
            ),
          ],
          const _SectionLabel('Información'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Acerca de KAIRO',
            onTap: _showAbout,
          ),
          const _SectionLabel('Sesión'),
          ListTile(
            leading: const Icon(Icons.logout, color: KairoColors.errorText),
            title: const Text('Cerrar sesión', style: TextStyle(color: KairoColors.errorText)),
            onTap: () async {
              await auth.signOut();
              if (context.mounted) context.go('/auth/signin');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: KairoColors.darkTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, color: KairoColors.darkTextSecondary),
      onTap: onTap,
    );
  }
}
