import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../auth/services/auth_service.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

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
