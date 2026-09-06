import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../users/services/users_repository.dart';

class PeopleSettingsView extends StatefulWidget {
  const PeopleSettingsView({super.key});

  @override
  State<PeopleSettingsView> createState() => _PeopleSettingsViewState();
}

class _PeopleSettingsViewState extends State<PeopleSettingsView> {
  final _repo = UsersRepository();
  List<KairoUser> _blocked = [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.listBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocked = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los bloqueos. Ejecuta la migración SQL 021.')),
      );
    }
  }

  Future<void> _unblock(KairoUser user) async {
    setState(() => _busyId = user.id);
    try {
      await _repo.unblockUser(user.id);
      if (!mounted) return;
      setState(() => _blocked.removeWhere((u) => u.id == user.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo desbloquear: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _removeFriend(KairoUser user) async {
    setState(() => _busyId = user.id);
    try {
      await _repo.removeFriendship(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} ya no está en tus amigos')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo quitar: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Personas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : RefreshIndicator(
              color: KairoColors.primary500,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 6),
                    child: Text(
                      'PERSONAS BLOQUEADAS',
                      style: TextStyle(
                        color: KairoColors.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Aquí se guardan las personas que bloqueaste. En los tres puntos puedes desbloquearlas o quitarlas de amigos.',
                      style: TextStyle(color: KairoColors.darkTextSecondary.withValues(alpha: 0.9), fontSize: 13, height: 1.35),
                    ),
                  ),
                  if (_blocked.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No hay personas bloqueadas', style: TextStyle(color: KairoColors.darkTextSecondary)),
                      ),
                    )
                  else
                    ..._blocked.map(_personTile),
                ],
              ),
            ),
    );
  }

  Widget _personTile(KairoUser user) {
    final busy = _busyId == user.id;
    return ListTile(
      leading: KairoAvatar(imageUrl: user.image, name: user.displayName, size: 44),
      title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: user.handle.isEmpty ? null : Text(user.handle),
      trailing: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary500),
            )
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: KairoColors.darkTextSecondary),
              color: KairoColors.darkCard,
              onSelected: (value) {
                if (value == 'unblock') _unblock(user);
                if (value == 'remove') _removeFriend(user);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'unblock', child: Text('Desbloquear')),
                PopupMenuItem(value: 'remove', child: Text('Eliminar de amigos')),
              ],
            ),
    );
  }
}
