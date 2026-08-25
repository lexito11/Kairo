import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/chat_group.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../messages/services/groups_repository.dart';
import '../widgets/group_invite_sheet.dart';
import '../widgets/group_message_composer.dart';
import '../widgets/group_settings_sheet.dart';

class GroupThreadView extends StatefulWidget {
  const GroupThreadView({super.key, required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;

  @override
  State<GroupThreadView> createState() => _GroupThreadViewState();
}

class _GroupThreadViewState extends State<GroupThreadView> {
  final _repo = GroupsRepository();
  final _scrollController = ScrollController();
  List<GroupChatMessage> _messages = [];
  ChatGroup? _group;
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.subscribeToGroupMessages(widget.groupId, (msg) {
      if (!mounted) return;
      if (_messages.any((m) => m.id == msg.id)) return;
      setState(() => _messages = [..._messages, msg]);
      _scrollToEnd();
    });
  }

  Future<void> _load() async {
    try {
      final group = await _repo.fetchGroup(widget.groupId);
      final list = await _repo.fetchGroupThread(widget.groupId);
      if (mounted) {
        setState(() {
          _group = group;
          _messages = list;
          _loading = false;
        });
      }
      _scrollToEnd();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage({
    required String text,
    Uint8List? mediaBytes,
    String? fileName,
    String? mimeType,
    String? stickerEmoji,
  }) async {
    try {
      GroupChatMessage msg;
      if (stickerEmoji != null) {
        msg = await _repo.sendGroupMessage(
          widget.groupId,
          content: stickerEmoji,
          mediaType: 'sticker',
        );
      } else if (mediaBytes != null && fileName != null && mimeType != null) {
        final uploaded = await _repo.uploadGroupMedia(
          bytes: mediaBytes,
          fileName: fileName,
          mimeType: mimeType,
          groupId: widget.groupId,
        );
        msg = await _repo.sendGroupMessage(
          widget.groupId,
          content: text,
          mediaUrl: uploaded.url,
          mediaType: uploaded.mediaType,
        );
      } else {
        msg = await _repo.sendGroupMessage(widget.groupId, content: text);
      }

      if (!_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages = [..._messages, msg]);
      }
      _scrollToEnd();
    } on AdminsOnlyChatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar: $e')),
        );
      }
    }
  }

  void _openInviteSheet() {
    showGroupInviteSheet(
      context,
      groupId: widget.groupId,
      groupName: _group?.name ?? widget.groupName,
    );
  }

  void _openSettings() {
    final group = _group;
    if (group == null || !group.isAdmin) return;
    showGroupSettingsSheet(
      context,
      group: group,
      onUpdated: _load,
    );
  }

  String _timeLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthService().currentUser?.id;
    final group = _group;
    final canInvite = group != null && group.isAdmin && !group.isPublic;
    final canSend = group?.canSendMessages ?? true;

    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _GroupHeader(
              name: group?.name ?? widget.groupName,
              isPublic: group?.isPublic ?? false,
              adminsOnlyChat: group?.adminsOnlyChat ?? false,
              memberCount: group?.memberCount,
              canInvite: canInvite,
              canManage: group?.isAdmin ?? false,
              onBack: () => context.pop(),
              onInvite: _openInviteSheet,
              onSettings: _openSettings,
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                group?.adminsOnlyChat == true && group?.isAdmin != true
                                    ? 'Solo los administradores pueden escribir en este grupo.'
                                    : group?.isPublic == true
                                        ? 'Grupo público. Escribe el primer mensaje.'
                                        : 'Grupo privado. Invita amigos para que se unan.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: KairoColors.darkTextSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[i];
                              final mine = myId != null && m.isMine(myId);
                              return Align(
                                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                child: _MessageBubble(
                                  message: m,
                                  mine: mine,
                                  timeLabel: _timeLabel(m.createdAt.toLocal()),
                                ),
                              );
                            },
                          ),
              ),
            ),
            GroupMessageComposer(
              canSend: canSend,
              readOnlyHint: group?.adminsOnlyChat == true
                  ? 'Solo los administradores pueden enviar mensajes.'
                  : null,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.timeLabel,
  });

  final GroupChatMessage message;
  final bool mine;
  final String timeLabel;

  Future<void> _openAudio(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      decoration: BoxDecoration(
        gradient: mine ? KairoColors.buttonGradient : null,
        color: mine ? null : KairoColors.darkCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.isSticker)
            Text(message.content, style: const TextStyle(fontSize: 48))
          else ...[
            if (message.isImage && message.hasMedia)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  width: 220,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                    width: 220,
                    height: 140,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            if (message.isAudio && message.hasMedia)
              InkWell(
                onTap: () => _openAudio(message.mediaUrl!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill, color: Colors.white.withValues(alpha: 0.9), size: 32),
                      const SizedBox(width: 10),
                      Text(
                        message.content.isNotEmpty ? message.content : 'Nota de voz',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (message.content.isNotEmpty && !message.isSticker && !message.isAudio)
              Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
              ),
          ],
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.onBack,
    required this.isPublic,
    this.adminsOnlyChat = false,
    this.memberCount,
    this.canInvite = false,
    this.canManage = false,
    this.onInvite,
    this.onSettings,
  });

  final String name;
  final VoidCallback onBack;
  final bool isPublic;
  final bool adminsOnlyChat;
  final int? memberCount;
  final bool canInvite;
  final bool canManage;
  final VoidCallback? onInvite;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final modeLabel = adminsOnlyChat ? 'Solo admins' : 'Chat abierto';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KairoColors.darkBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: KairoColors.darkText),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: KairoColors.buttonGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: KairoColors.darkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${memberCount ?? 1} miembros · ${isPublic ? 'Público' : 'Privado'} · $modeLabel',
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              onPressed: onSettings,
              tooltip: 'Ajustes',
              icon: const Icon(Icons.settings_outlined, color: KairoColors.primary400),
            ),
          if (canInvite)
            IconButton(
              onPressed: onInvite,
              tooltip: 'Invitar',
              icon: const Icon(Icons.person_add_alt_1, color: KairoColors.primary400),
            ),
        ],
      ),
    );
  }
}
