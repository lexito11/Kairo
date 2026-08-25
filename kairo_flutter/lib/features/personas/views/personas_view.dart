import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../users/services/users_repository.dart';

enum _PersonasTab { incoming, outgoing, friends }

class PersonasView extends StatefulWidget {
  const PersonasView({super.key});

  @override
  State<PersonasView> createState() => _PersonasViewState();
}

class _PersonasViewState extends State<PersonasView> {
  final _repo = UsersRepository();
  final _search = TextEditingController();

  _PersonasTab _tab = _PersonasTab.incoming;
  bool _loading = true;
  String? _error;
  String? _busyUserId;

  List<PersonaEntry> _incoming = [];
  List<PersonaEntry> _outgoing = [];
  List<PersonaEntry> _friends = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final incoming = await _repo.getIncomingFollows();
      final outgoing = await _repo.getOutgoingFollows();
      final friends = outgoing.where((e) => e.isFriend).toList();
      if (!mounted) return;
      setState(() {
        _incoming = incoming.where((e) => e.isIncomingPending).toList();
        _outgoing = outgoing.where((e) => e.isPendingOutgoing).toList();
        _friends = friends;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar Personas';
      });
    }
  }

  List<PersonaEntry> get _currentList {
    final q = _search.text.trim().toLowerCase();
    List<PersonaEntry> base;
    switch (_tab) {
      case _PersonasTab.incoming:
        base = _incoming;
      case _PersonasTab.outgoing:
        base = _outgoing;
      case _PersonasTab.friends:
        base = _friends;
    }
    if (q.isEmpty) return base;
    return base.where((e) {
      final name = e.user.displayName.toLowerCase();
      final username = (e.user.username ?? '').toLowerCase();
      final bio = (e.user.bio ?? '').toLowerCase();
      return name.contains(q) || username.contains(q) || bio.contains(q);
    }).toList();
  }

  String get _sectionLabel {
    final n = _currentList.length;
    switch (_tab) {
      case _PersonasTab.incoming:
        return n == 1 ? '1 solicitud pendiente' : '$n solicitudes pendientes';
      case _PersonasTab.outgoing:
        return n == 1 ? '1 esperando respuesta' : '$n esperando respuesta';
      case _PersonasTab.friends:
        return n == 1 ? '1 amigo' : '$n amigos';
    }
  }

  Future<void> _confirm(PersonaEntry entry) async {
    setState(() => _busyUserId = entry.user.id);
    try {
      await _repo.follow(entry.user.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo confirmar')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _removeIncoming(PersonaEntry entry) async {
    setState(() => _busyUserId = entry.user.id);
    try {
      await _repo.removeFollower(entry.user.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar. Revisa permisos en Supabase.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _cancelOutgoing(PersonaEntry entry) async {
    setState(() => _busyUserId = entry.user.id);
    try {
      await _repo.unfollow(entry.user.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _unfriend(PersonaEntry entry) async {
    setState(() => _busyUserId = entry.user.id);
    try {
      await _repo.unfollow(entry.user.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _SearchField(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _Tabs(
                tab: _tab,
                incomingCount: _incoming.length,
                friendsCount: _friends.length,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: KairoColors.darkBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _sectionLabel,
                style: const TextStyle(
                  color: KairoColors.darkTextSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KairoColors.primary500),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: KairoColors.darkTextSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final items = _currentList;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _emptyMessage,
          style: const TextStyle(color: KairoColors.darkTextSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      color: KairoColors.primary500,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final entry = items[i];
          final busy = _busyUserId == entry.user.id;
          return switch (_tab) {
            _PersonasTab.incoming => _IncomingCard(
                entry: entry,
                busy: busy,
                onConfirm: () => _confirm(entry),
                onRemove: () => _removeIncoming(entry),
              ),
            _PersonasTab.outgoing => _OutgoingCard(
                entry: entry,
                busy: busy,
                onCancel: () => _cancelOutgoing(entry),
              ),
            _PersonasTab.friends => _FriendCard(
                entry: entry,
                busy: busy,
                onUnfriend: () => _unfriend(entry),
              ),
          };
        },
      ),
    );
  }

  String get _emptyMessage {
    switch (_tab) {
      case _PersonasTab.incoming:
        return 'No tienes solicitudes pendientes';
      case _PersonasTab.outgoing:
        return 'No hay agregados esperando respuesta';
      case _PersonasTab.friends:
        return 'Aún no tienes amigos';
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: KairoColors.darkText),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personas',
                  style: TextStyle(
                    color: KairoColors.darkText,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Encuentra y conecta con hermanos',
                  style: TextStyle(
                    color: KairoColors.darkTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: KairoColors.primary400, width: 1.5),
            ),
            child: const Icon(Icons.person_add_alt_1, color: KairoColors.primary400, size: 22),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: KairoColors.darkText, fontSize: 15),
      cursorColor: KairoColors.primary400,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre...',
        hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 15),
        prefixIcon: const Icon(Icons.search, color: KairoColors.darkTextSecondary),
        filled: true,
        fillColor: KairoColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.incomingCount,
    required this.friendsCount,
    required this.onChanged,
  });

  final _PersonasTab tab;
  final int incomingCount;
  final int friendsCount;
  final ValueChanged<_PersonasTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TabChip(
            label: 'Me agregaron',
            badge: incomingCount > 0 ? '$incomingCount' : null,
            selected: tab == _PersonasTab.incoming,
            onTap: () => onChanged(_PersonasTab.incoming),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Agregados',
            selected: tab == _PersonasTab.outgoing,
            onTap: () => onChanged(_PersonasTab.outgoing),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Amigos',
            badge: friendsCount > 0 ? '$friendsCount' : null,
            selected: tab == _PersonasTab.friends,
            onTap: () => onChanged(_PersonasTab.friends),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KairoColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : KairoColors.darkTextSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : KairoColors.primary500.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: selected ? Colors.white : KairoColors.primary300,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.entry,
    required this.busy,
    required this.onConfirm,
    required this.onRemove,
  });

  final PersonaEntry entry;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _PersonaRow(
      entry: entry,
      badge: _AvatarBadge.personAdd,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            label: 'Confirmar',
            icon: Icons.check,
            filled: true,
            busy: busy,
            onTap: onConfirm,
          ),
          const SizedBox(height: 6),
          _ActionButton(
            label: 'Eliminar',
            icon: Icons.close,
            filled: false,
            busy: busy,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _OutgoingCard extends StatelessWidget {
  const _OutgoingCard({
    required this.entry,
    required this.busy,
    required this.onCancel,
  });

  final PersonaEntry entry;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _PersonaRow(
      entry: entry,
      trailing: _ActionButton(
        label: 'Pendiente',
        icon: Icons.schedule,
        filled: false,
        busy: busy,
        onTap: onCancel,
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.entry,
    required this.busy,
    required this.onUnfriend,
  });

  final PersonaEntry entry;
  final bool busy;
  final VoidCallback onUnfriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      child: _PersonaRow(
        entry: entry,
        badge: _AvatarBadge.friend,
        padded: false,
        trailing: _ActionButton(
          label: 'Amigos',
          icon: Icons.person_outline,
          filled: false,
          outlinedCyan: true,
          busy: busy,
          onTap: onUnfriend,
        ),
      ),
    );
  }
}

enum _AvatarBadge { none, personAdd, friend }

class _PersonaRow extends StatelessWidget {
  const _PersonaRow({
    required this.entry,
    required this.trailing,
    this.badge = _AvatarBadge.none,
    this.padded = true,
  });

  final PersonaEntry entry;
  final Widget trailing;
  final _AvatarBadge badge;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            KairoAvatar(
              imageUrl: entry.user.image,
              name: entry.user.displayName,
              size: 52,
              onTap: () => context.push('/profile?userId=${entry.user.id}'),
            ),
            if (badge != _AvatarBadge.none)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: badge == _AvatarBadge.friend
                        ? KairoColors.primary500
                        : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: KairoColors.darkBg, width: 2),
                  ),
                  child: Icon(
                    badge == _AvatarBadge.friend ? Icons.check : Icons.person,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/profile?userId=${entry.user.id}'),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.user.displayName,
                  style: const TextStyle(
                    color: KairoColors.darkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    color: KairoColors.darkTextSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: KairoColors.primary300),
                    children: [
                      if (entry.mutualCount > 0)
                        TextSpan(text: '${entry.mutualCount} en común  '),
                      if (entry.followedAt != null)
                        TextSpan(
                          text: _capitalize(formatTimeAgo(entry.followedAt!)),
                          style: const TextStyle(color: KairoColors.darkTextSecondary),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );

    if (!padded) return content;
    return content;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.busy,
    required this.onTap,
    this.outlinedCyan = false,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final bool outlinedCyan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? KairoColors.primary500
        : outlinedCyan
            ? Colors.transparent
            : KairoColors.darkHover;
    final fg = filled
        ? Colors.white
        : outlinedCyan
            ? KairoColors.primary400
            : KairoColors.darkText;
    final border = outlinedCyan
        ? Border.all(color: KairoColors.primary400)
        : filled
            ? null
            : Border.all(color: KairoColors.darkBorder);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 108),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 15, color: fg),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
