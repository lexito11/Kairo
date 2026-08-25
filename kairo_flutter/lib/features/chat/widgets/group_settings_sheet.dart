import 'package:flutter/material.dart';

import '../../../core/constants/chat_limits.dart';
import '../../../core/models/chat_group.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../auth/services/auth_service.dart';
import '../../messages/services/groups_repository.dart';

Future<void> showGroupSettingsSheet(
  BuildContext context, {
  required ChatGroup group,
  required VoidCallback onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupSettingsSheet(group: group, onUpdated: onUpdated),
  );
}

class _GroupSettingsSheet extends StatefulWidget {
  const _GroupSettingsSheet({required this.group, required this.onUpdated});

  final ChatGroup group;
  final VoidCallback onUpdated;

  @override
  State<_GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<_GroupSettingsSheet> {
  final _repo = GroupsRepository();
  late bool _adminsOnly;
  List<GroupMember> _members = [];
  int _adminCount = 1;
  bool _loading = true;
  bool _saving = false;

  String? get _myId => AuthService().currentUser?.id;

  @override
  void initState() {
    super.initState();
    _adminsOnly = widget.group.adminsOnlyChat;
    _adminCount = widget.group.adminCount;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _repo.fetchGroupMembers(widget.group.id);
      if (mounted) {
        setState(() {
          _members = members;
          _adminCount = members.where((m) => m.isAdmin).length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAdminsOnly(bool value) async {
    setState(() => _saving = true);
    try {
      await _repo.setAdminsOnlyChat(widget.group.id, value);
      if (mounted) {
        setState(() => _adminsOnly = value);
        widget.onUpdated();
      }
    } on NotGroupAdminException catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAdmin(GroupMember member) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repo.setMemberRole(
        widget.group.id,
        member.userId,
        asAdmin: !member.isAdmin,
      );
      await _loadMembers();
      widget.onUpdated();
    } on MaxAdminsException catch (e) {
      _showError(e.toString());
    } on LastAdminException catch (e) {
      _showError(e.toString());
    } on NotGroupAdminException catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                        'Ajustes del grupo',
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
              SwitchListTile(
                title: const Text(
                  'Solo administradores escriben',
                  style: TextStyle(color: KairoColors.darkText),
                ),
                subtitle: const Text(
                  'Desactivado: chat normal para todos los miembros.',
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
                value: _adminsOnly,
                activeThumbColor: KairoColors.primary500,
                onChanged: _saving ? null : _toggleAdminsOnly,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Text(
                      'Administradores ($_adminCount/${ChatLimits.maxAdminsPerGroup})',
                      style: const TextStyle(
                        color: KairoColors.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Máximo ${ChatLimits.maxAdminsPerGroup} administradores por grupo.',
                    style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
                    : ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(8, 0, 8, bottom + 16),
                        itemCount: _members.length,
                        itemBuilder: (_, i) {
                          final member = _members[i];
                          final isMe = member.userId == _myId;
                          final canPromote = !member.isAdmin &&
                              _adminCount < ChatLimits.maxAdminsPerGroup;
                          final canDemote = member.isAdmin && _adminCount > 1;

                          return ListTile(
                            leading: KairoAvatar(
                              imageUrl: member.imageUrl,
                              name: member.displayName,
                              size: 40,
                            ),
                            title: Text(
                              isMe ? '${member.displayName} (tú)' : member.displayName,
                              style: const TextStyle(color: KairoColors.darkText),
                            ),
                            subtitle: Text(
                              member.isAdmin ? 'Administrador' : 'Miembro',
                              style: TextStyle(
                                color: member.isAdmin ? KairoColors.primary400 : KairoColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: member.isAdmin
                                ? (canDemote
                                    ? TextButton(
                                        onPressed: () => _toggleAdmin(member),
                                        child: const Text('Quitar admin'),
                                      )
                                    : null)
                                : (canPromote
                                    ? TextButton(
                                        onPressed: () => _toggleAdmin(member),
                                        child: const Text('Hacer admin'),
                                      )
                                    : null),
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
