import 'package:flutter/material.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../messages/services/groups_repository.dart';
import '../../users/services/users_repository.dart';

Future<void> showGroupInviteSheet(
  BuildContext context, {
  required String groupId,
  required String groupName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupInviteSheet(groupId: groupId, groupName: groupName),
  );
}

class _GroupInviteSheet extends StatefulWidget {
  const _GroupInviteSheet({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;

  @override
  State<_GroupInviteSheet> createState() => _GroupInviteSheetState();
}

class _GroupInviteSheetState extends State<_GroupInviteSheet> {
  final _usersRepo = UsersRepository();
  final _groupsRepo = GroupsRepository();
  final _search = TextEditingController();

  List<PersonaEntry> _friends = [];
  bool _loading = true;
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final friends = await _usersRepo.getFriends();
      if (mounted) setState(() { _friends = friends; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PersonaEntry> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends.where((e) {
      final name = e.user.displayName.toLowerCase();
      final username = (e.user.username ?? '').toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  Future<void> _invite(KairoUser user) async {
    setState(() => _busyUserId = user.id);
    try {
      await _groupsRepo.inviteUser(widget.groupId, user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitación enviada a ${user.displayName}')),
      );
      Navigator.pop(context);
    } on AlreadyMemberException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo invitar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final list = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invitar al grupo',
                      style: TextStyle(
                        color: KairoColors.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.groupName,
                      style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
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
                              'No hay amigos para invitar',
                              style: TextStyle(color: KairoColors.darkTextSecondary),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final entry = list[i];
                              final user = entry.user;
                              final busy = _busyUserId == user.id;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: KairoAvatar(
                                  imageUrl: user.image,
                                  name: user.displayName,
                                  size: 44,
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    color: KairoColors.darkText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: user.username != null
                                    ? Text(
                                        '@${user.username}',
                                        style: const TextStyle(color: KairoColors.darkTextSecondary),
                                      )
                                    : null,
                                trailing: TextButton(
                                  onPressed: busy ? null : () => _invite(user),
                                  child: busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Invitar'),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
