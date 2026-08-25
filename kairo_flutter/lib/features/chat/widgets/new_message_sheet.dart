import 'package:flutter/material.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../users/services/users_repository.dart';

Future<KairoUser?> showNewMessageSheet(BuildContext context) {
  return showModalBottomSheet<KairoUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NewMessageSheet(),
  );
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet();

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _usersRepo = UsersRepository();
  final _search = TextEditingController();

  List<PersonaEntry> _friends = [];
  List<KairoUser> _searchResults = [];
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _usersRepo.getFriends();
      if (mounted) setState(() { _friends = friends; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _searchGen = 0;

  Future<void> _onSearchChanged() async {
    setState(() {});
    final q = _search.text.trim();
    final gen = ++_searchGen;
    if (q.length < 2) {
      if (_searchResults.isNotEmpty) setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted || gen != _searchGen) return;

    try {
      final results = await _usersRepo.searchUsers(q);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      if (mounted && gen == _searchGen) {
        setState(() => _searching = false);
      }
    }
  }

  List<PersonaEntry> get _filteredFriends {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends.where((e) {
      final name = e.user.displayName.toLowerCase();
      final username = (e.user.username ?? '').toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  void _openChat(KairoUser user) {
    Navigator.pop(context, user);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final q = _search.text.trim();
    final friends = _filteredFriends;
    final friendIds = _friends.map((e) => e.user.id).toSet();
    final extraSearch = q.length >= 2
        ? _searchResults.where((u) => !friendIds.contains(u.id)).toList()
        : <KairoUser>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KairoColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nuevo mensaje',
                        style: TextStyle(
                          color: KairoColors.darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: KairoColors.darkTextSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: KairoColors.darkText),
                  decoration: InputDecoration(
                    hintText: 'Buscar amigos o usuarios...',
                    hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                    prefixIcon: const Icon(Icons.search, color: KairoColors.darkTextSecondary),
                    filled: true,
                    fillColor: KairoColors.darkBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
                      : ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 16),
                          children: [
                            if (friends.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                                child: Text(
                                  'Amigos',
                                  style: TextStyle(
                                    color: KairoColors.darkTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...friends.map((e) => _UserTile(
                                    user: e.user,
                                    subtitle: e.user.username != null ? '@${e.user.username}' : 'Amigo',
                                    onTap: () => _openChat(e.user),
                                  )),
                            ],
                            if (_searching)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: KairoColors.primary400,
                                    ),
                                  ),
                                ),
                              )
                            else if (extraSearch.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                                child: Text(
                                  'Usuarios',
                                  style: TextStyle(
                                    color: KairoColors.darkTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...extraSearch.map((u) => _UserTile(
                                    user: u,
                                    subtitle: u.username != null ? '@${u.username}' : 'Usuario de KAIRO',
                                    onTap: () => _openChat(u),
                                  )),
                            ],
                            if (!_searching && friends.isEmpty && extraSearch.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                                child: Text(
                                  q.length >= 2
                                      ? 'No se encontraron usuarios'
                                      : 'Aún no tienes amigos. Agrégalos en Personas para chatear, o búscalos por nombre.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: KairoColors.darkTextSecondary),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.subtitle,
    required this.onTap,
  });

  final KairoUser user;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: KairoAvatar(imageUrl: user.image, name: user.displayName, size: 44),
      title: Text(user.displayName, style: const TextStyle(color: KairoColors.darkText)),
      subtitle: Text(subtitle, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chat_bubble_outline, color: KairoColors.primary400, size: 20),
    );
  }
}
