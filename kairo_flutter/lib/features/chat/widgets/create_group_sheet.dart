import 'package:flutter/material.dart';
import '../../../core/constants/chat_limits.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../users/services/users_repository.dart';

class CreateGroupResult {
  const CreateGroupResult({
    required this.name,
    required this.isPublic,
    required this.adminsOnlyChat,
    required this.inviteeIds,
  });

  final String name;
  final bool isPublic;
  final bool adminsOnlyChat;
  final List<String> inviteeIds;
}

Future<CreateGroupResult?> showCreateGroupSheet(BuildContext context) {
  return showModalBottomSheet<CreateGroupResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateGroupSheet(),
  );
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _usersRepo = UsersRepository();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  List<PersonaEntry> _friends = [];
  final Set<String> _selected = {};
  bool _isPublic = false;
  bool _adminsOnlyChat = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
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

  List<PersonaEntry> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends.where((e) {
      final name = e.user.displayName.toLowerCase();
      final username = (e.user.username ?? '').toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  bool get _canCreate {
    final name = _nameController.text.trim();
    return name.length >= 2 && _selected.length >= ChatLimits.minInviteesToCreateGroup;
  }

  void _toggleUser(KairoUser user) {
    setState(() {
      if (_selected.contains(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected.add(user.id);
      }
    });
  }

  void _submit() {
    if (!_canCreate) return;
    Navigator.pop(
      context,
      CreateGroupResult(
        name: _nameController.text.trim(),
        isPublic: _isPublic,
        adminsOnlyChat: _adminsOnlyChat,
        inviteeIds: _selected.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final list = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Crear grupo',
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
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: KairoColors.darkText),
                  decoration: InputDecoration(
                    hintText: 'Nombre del grupo',
                    hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                    filled: true,
                    fillColor: KairoColors.darkBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Grupo público', style: TextStyle(color: KairoColors.darkText)),
                subtitle: const Text(
                  'Público: cualquiera puede entrar. Privado: solo con invitación.',
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
                value: _isPublic,
                activeThumbColor: KairoColors.primary500,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
              SwitchListTile(
                title: const Text('Solo administradores escriben', style: TextStyle(color: KairoColors.darkText)),
                subtitle: const Text(
                  'Si está desactivado, todos los miembros pueden chatear con emojis, imágenes y audios.',
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
                value: _adminsOnlyChat,
                activeThumbColor: KairoColors.primary500,
                onChanged: (v) => setState(() => _adminsOnlyChat = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Invitar (${_selected.length}/${ChatLimits.minInviteesToCreateGroup} mín.)',
                        style: const TextStyle(
                          color: KairoColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_selected.length < ChatLimits.minInviteesToCreateGroup)
                      Text(
                        'Faltan ${ChatLimits.minInviteesToCreateGroup - _selected.length}',
                        style: const TextStyle(color: KairoColors.primary400, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: KairoColors.darkText),
                  decoration: InputDecoration(
                    hintText: 'Buscar amigos...',
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
                    : list.isEmpty
                        ? const Center(
                            child: Text(
                              'Necesitas amigos para crear un grupo',
                              style: TextStyle(color: KairoColors.darkTextSecondary),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 80),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final entry = list[i];
                              final user = entry.user;
                              final selected = _selected.contains(user.id);
                              return CheckboxListTile(
                                value: selected,
                                activeColor: KairoColors.primary500,
                                onChanged: (_) => _toggleUser(user),
                                secondary: KairoAvatar(
                                  imageUrl: user.image,
                                  name: user.displayName,
                                  size: 40,
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(color: KairoColors.darkText),
                                ),
                                subtitle: user.username != null
                                    ? Text(
                                        '@${user.username}',
                                        style: const TextStyle(color: KairoColors.darkTextSecondary),
                                      )
                                    : null,
                              );
                            },
                          ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canCreate ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: KairoColors.primary500,
                      disabledBackgroundColor: KairoColors.darkHover,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Crear grupo'),
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
