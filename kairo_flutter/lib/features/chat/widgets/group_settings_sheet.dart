import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/chat_limits.dart';
import '../../../core/models/chat_group.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../auth/services/auth_service.dart';
import '../../messages/services/groups_repository.dart';
import '../services/group_content_policy.dart';
import 'group_avatar.dart';

Future<void> showGroupSettingsSheet(
  BuildContext context, {
  required ChatGroup group,
  required VoidCallback onUpdated,
  VoidCallback? onLeft,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupSettingsSheet(
      group: group,
      onUpdated: onUpdated,
      onLeft: onLeft,
    ),
  );
}

Future<bool> confirmLeaveGroup(
  BuildContext context, {
  required bool isLastMember,
  required bool needsAdminTransfer,
}) async {
  final message = needsAdminTransfer
      ? 'Eres el único administrador. Promueve a otro miembro antes de salir.'
      : isLastMember
          ? 'Eres el último miembro. Si sales, el grupo se eliminará.'
          : 'Dejarás de ver este grupo y sus mensajes.';

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: KairoColors.darkCard,
      title: const Text('Salir del grupo', style: TextStyle(color: KairoColors.darkText)),
      content: Text(message, style: const TextStyle(color: KairoColors.darkTextSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        if (!needsAdminTransfer)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isLastMember ? 'Salir y eliminar' : 'Salir',
              style: const TextStyle(color: Color(0xFFF87171)),
            ),
          ),
      ],
    ),
  );
  return result == true;
}

class _GroupSettingsSheet extends StatefulWidget {
  const _GroupSettingsSheet({
    required this.group,
    required this.onUpdated,
    this.onLeft,
  });

  final ChatGroup group;
  final VoidCallback onUpdated;
  final VoidCallback? onLeft;

  @override
  State<_GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<_GroupSettingsSheet> {
  final _repo = GroupsRepository();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  late bool _adminsOnly;
  late String? _imageUrl;
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
    _imageUrl = widget.group.imageUrl;
    _descriptionController.text = widget.group.description ?? '';
    _loadMembers();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _saveProfile({
    Uint8List? imageBytes,
    String? imageFileName,
    String? imageMimeType,
  }) async {
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateGroupProfile(
        widget.group.id,
        description: _descriptionController.text,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        imageMimeType: imageMimeType,
      );
      if (!mounted) return;
      setState(() => _imageUrl = updated.imageUrl);
      widget.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del grupo actualizados')),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      GroupContentPolicy.validateImage(bytes: bytes, mimeType: file.mimeType ?? '');
      await _saveProfile(
        imageBytes: bytes,
        imageFileName: file.name,
        imageMimeType: file.mimeType ?? 'image/jpeg',
      );
    } on GroupImageException catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _leave() async {
    final needsTransfer = widget.group.isAdmin && _adminCount <= 1 && _members.length > 1;
    final confirmed = await confirmLeaveGroup(
      context,
      isLastMember: _members.length <= 1,
      needsAdminTransfer: needsTransfer,
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await _repo.leaveGroup(widget.group.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onLeft?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saliste del grupo')),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : _pickImage,
                      child: Stack(
                        children: [
                          GroupAvatar(imageUrl: _imageUrl, size: 64),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: KairoColors.primary500,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Toca para cambiar la imagen. No se permite contenido sexual, desnudez, bikini ni ropa interior.',
                        style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _descriptionController,
                  maxLength: ChatLimits.maxGroupDescriptionLength,
                  minLines: 2,
                  maxLines: 3,
                  enabled: !_saving,
                  style: const TextStyle(color: KairoColors.darkText),
                  decoration: InputDecoration(
                    hintText: 'Descripción del grupo',
                    hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                    filled: true,
                    fillColor: KairoColors.darkBg,
                    counterStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving ? null : () => _saveProfile(),
                    child: const Text('Guardar descripción'),
                  ),
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
                        padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
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
              Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _leave,
                    icon: const Icon(Icons.logout, color: Color(0xFFF87171)),
                    label: const Text(
                      'Salir del grupo',
                      style: TextStyle(color: Color(0xFFF87171)),
                    ),
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
