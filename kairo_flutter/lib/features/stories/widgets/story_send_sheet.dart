import 'package:flutter/material.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/models/story.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../messages/services/messages_repository.dart';
import '../../users/services/users_repository.dart';

Future<void> showStorySendSheet(BuildContext context, {required Story story}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StorySendSheet(story: story),
  );
}

class _StorySendSheet extends StatefulWidget {
  const _StorySendSheet({required this.story});

  final Story story;

  @override
  State<_StorySendSheet> createState() => _StorySendSheetState();
}

class _StorySendSheetState extends State<_StorySendSheet> {
  final _usersRepo = UsersRepository();
  final _messagesRepo = MessagesRepository();
  final _search = TextEditingController();

  List<PersonaEntry> _friends = [];
  List<KairoUser> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String? _sendingId;
  final _sentIds = <String>{};
  int _searchGen = 0;

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
      if (mounted) {
        setState(() {
          _friends = friends;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      if (mounted && gen == _searchGen) setState(() => _searching = false);
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

  Future<void> _sendTo(KairoUser user) async {
    if (_sendingId != null || _sentIds.contains(user.id)) return;
    setState(() => _sendingId = user.id);
    try {
      await _messagesRepo.sendMessage(
        user.id,
        'Te envió una historia',
        mediaUrl: widget.story.mediaUrl,
        mediaType: widget.story.mediaType,
      );
      if (!mounted) return;
      setState(() {
        _sentIds.add(user.id);
        _sendingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Historia enviada a ${user.displayName}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la historia')),
      );
    }
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
      initialChildSize: 0.72,
      minChildSize: 0.45,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enviar a',
                    style: TextStyle(
                      color: KairoColors.darkText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  style: const TextStyle(color: KairoColors.darkText),
                  decoration: InputDecoration(
                    hintText: 'Buscar amigos...',
                    hintStyle:
                        const TextStyle(color: KairoColors.darkTextSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: KairoColors.darkTextSecondary),
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
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: KairoColors.primary500))
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
                              ...friends.map((e) => _SendTile(
                                    user: e.user,
                                    sending: _sendingId == e.user.id,
                                    sent: _sentIds.contains(e.user.id),
                                    onTap: () => _sendTo(e.user),
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
                              ...extraSearch.map((u) => _SendTile(
                                    user: u,
                                    sending: _sendingId == u.id,
                                    sent: _sentIds.contains(u.id),
                                    onTap: () => _sendTo(u),
                                  )),
                            ],
                            if (!_searching &&
                                friends.isEmpty &&
                                extraSearch.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 48, horizontal: 24),
                                child: Text(
                                  q.length >= 2
                                      ? 'No se encontraron usuarios'
                                      : 'Aún no tienes amigos. Agrégalos en Personas para enviarles historias.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: KairoColors.darkTextSecondary),
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

class _SendTile extends StatelessWidget {
  const _SendTile({
    required this.user,
    required this.sending,
    required this.sent,
    required this.onTap,
  });

  final KairoUser user;
  final bool sending;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: sent || sending ? null : onTap,
      leading:
          KairoAvatar(imageUrl: user.image, name: user.displayName, size: 44),
      title: Text(user.displayName,
          style: const TextStyle(color: KairoColors.darkText)),
      subtitle: Text(
        user.username != null ? '@${user.username}' : 'Enviar historia',
        style:
            const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
      ),
      trailing: sent
          ? const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 22)
          : sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: KairoColors.primary400),
                )
              : const Icon(Icons.send, color: KairoColors.primary400, size: 20),
    );
  }
}
