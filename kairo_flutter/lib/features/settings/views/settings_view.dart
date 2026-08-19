import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../events/services/churches_repository.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final Future<bool> _adminFuture = ChurchesRepository().isCurrentUserAdmin();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tema oscuro'),
            subtitle: Text(theme.isDark ? 'Modo oscuro activo' : 'Modo claro activo'),
            value: theme.isDark,
            activeThumbColor: KairoColors.primary500,
            onChanged: theme.toggle,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Eventos'),
            onTap: () => context.push('/events'),
          ),
          FutureBuilder<bool>(
            future: _adminFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined, color: KairoColors.primary400),
                title: const Text('Solicitudes de iglesias'),
                subtitle: const Text('Revisar y aprobar registros pendientes'),
                onTap: () => context.push('/admin/churches'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: KairoColors.errorText),
            title: const Text('Cerrar sesión', style: TextStyle(color: KairoColors.errorText)),
            onTap: () async {
              await auth.signOut();
              if (context.mounted) context.go('/auth/signin');
            },
          ),
        ],
      ),
    );
  }
}
