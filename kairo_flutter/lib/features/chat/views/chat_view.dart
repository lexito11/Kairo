import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/chat_limits.dart';
import '../../../core/models/chat_group.dart';
import '../../../core/models/message.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/new_message_sheet.dart';
import '../../messages/services/groups_repository.dart';
import '../../messages/services/messages_repository.dart';

enum _ChatFilter { all, unread, pinned, groups }
enum _GroupsSection { mine, all }

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _repo = MessagesRepository();
  final _groupsRepo = GroupsRepository();
  final _prefs = PrefsService();
  final _search = TextEditingController();

  List<Conversation> _conversations = [];
  List<ChatGroup> _groups = [];
  List<ChatGroup> _allGroups = [];
  int _createdGroupsCount = 0;
  Set<String> _pinnedIds = {};
  _ChatFilter _filter = _ChatFilter.all;
  _GroupsSection _groupsSection = _GroupsSection.mine;
  bool _loading = true;

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
    setState(() => _loading = true);
    try {
      final pinned = await _prefs.getPinnedChatIds();
      final list = await _repo.fetchConversations();
      List<ChatGroup> groups = [];
      List<ChatGroup> allGroups = [];
      var createdCount = 0;
      try {
        groups = await _groupsRepo.fetchMyGroups();
        allGroups = await _groupsRepo.fetchAllGroups();
        createdCount = await _groupsRepo.countCreatedGroups();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _pinnedIds = pinned.toSet();
        _conversations = list;
        _groups = groups;
        _allGroups = allGroups;
        _createdGroupsCount = createdCount;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _unreadTotal =>
      _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  int get _pinnedCount =>
      _conversations.where((c) => _pinnedIds.contains(c.otherUser.id)).length;

  List<Conversation> get _filtered {
    final q = _search.text.trim().toLowerCase();
    Iterable<Conversation> list = _conversations;

    switch (_filter) {
      case _ChatFilter.all:
        break;
      case _ChatFilter.unread:
        list = list.where((c) => c.unreadCount > 0);
      case _ChatFilter.pinned:
        list = list.where((c) => _pinnedIds.contains(c.otherUser.id));
      case _ChatFilter.groups:
        break;
    }

    if (q.isNotEmpty) {
      list = list.where((c) {
        final name = c.otherUser.displayName.toLowerCase();
        final preview = c.lastMessage.content.toLowerCase();
        return name.contains(q) || preview.contains(q);
      });
    }
    return list.toList();
  }

  List<Conversation> get _pinnedSection =>
      _filtered.where((c) => _pinnedIds.contains(c.otherUser.id)).toList();

  List<Conversation> get _messagesSection =>
      _filtered.where((c) => !_pinnedIds.contains(c.otherUser.id)).toList();

  List<ChatGroup> get _filteredGroups {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _groups;
    return _groups.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _setPin(Conversation c, {required bool pin}) async {
    final result = await _prefs.setChatPinned(c.otherUser.id, pin: pin);
    if (!mounted) return;

    switch (result) {
      case PinChatResult.pinned:
        setState(() => _pinnedIds.add(c.otherUser.id));
        if (pin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat fijado')),
          );
        }
      case PinChatResult.unpinned:
        setState(() => _pinnedIds.remove(c.otherUser.id));
        if (!pin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat desfijado')),
          );
        }
      case PinChatResult.limitReached:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solo puedes fijar ${ChatLimits.maxPinnedChats} chats. Quita uno para fijar otro.',
            ),
          ),
        );
    }
  }

  List<ChatGroup> get _discoverGroups {
    final q = _search.text.trim().toLowerCase();
    var list = _allGroups.where((g) => !g.isMember);
    if (q.isNotEmpty) {
      list = list.where((g) => g.name.toLowerCase().contains(q));
    }
    return list.toList();
  }

  Future<void> _createGroup() async {
    if (_createdGroupsCount >= ChatLimits.maxGroupsCreatedPerUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solo puedes crear ${ChatLimits.maxGroupsCreatedPerUser} grupos.',
          ),
        ),
      );
      return;
    }

    final result = await showCreateGroupSheet(context);
    if (result == null || !mounted) return;

    try {
      final group = await _groupsRepo.createGroupWithInvites(
        name: result.name,
        isPublic: result.isPublic,
        adminsOnlyChat: result.adminsOnlyChat,
        inviteeIds: result.inviteeIds,
      );
      if (!mounted) return;
      setState(() {
        _filter = _ChatFilter.groups;
        _groupsSection = _GroupsSection.mine;
      });
      await _load();
      _openGroup(group);
    } on GroupLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } on MinInviteesException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } on InvalidGroupNameException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear el grupo: $e')),
        );
      }
    }
  }

  Future<void> _joinPublicGroup(ChatGroup group) async {
    try {
      final joined = await _groupsRepo.joinPublicGroup(group.id);
      if (!mounted) return;
      await _load();
      _openGroup(joined);
    } on GroupFullException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo entrar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadTotal;

    return MainScaffold(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                unreadCount: unread,
                showCreateGroup: _filter == _ChatFilter.groups,
                onCompose: () {
                  if (_filter == _ChatFilter.groups) {
                    _createGroup();
                  } else {
                    _composeNewMessage();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _SearchField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _FilterBlock(
                  filter: _filter,
                  allCount: _conversations.length,
                  unreadCount: unread,
                  pinnedCount: _pinnedCount,
                  groupsCount: _groups.length,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),
              if (_filter == _ChatFilter.groups)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _GroupsSectionTabs(
                    section: _groupsSection,
                    onChanged: (s) => setState(() => _groupsSection = s),
                  ),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
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

    if (_filter == _ChatFilter.groups) {
      if (_groupsSection == _GroupsSection.mine) {
        final groups = _filteredGroups;
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Aún no estás en ningún grupo',
                  style: TextStyle(color: KairoColors.darkTextSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Crea uno (mín. ${ChatLimits.minInviteesToCreateGroup} invitados) o entra en Todos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _createGroup,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Crear grupo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KairoColors.primary500,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: KairoColors.primary500,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              Text(
                '$_createdGroupsCount/${ChatLimits.maxGroupsCreatedPerUser} grupos creados',
                style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...groups.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GroupTile(group: g, onTap: () => _openGroup(g)),
                ),
              ),
            ],
          ),
        );
      }

      final discover = _discoverGroups;
      if (discover.isEmpty) {
        return const Center(
          child: Text(
            'No hay más grupos por descubrir',
            style: TextStyle(color: KairoColors.darkTextSecondary),
          ),
        );
      }

      return RefreshIndicator(
        color: KairoColors.primary500,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: discover.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GroupTile(
                group: g,
                onTap: g.isPublic ? () => _joinPublicGroup(g) : null,
                actionLabel: g.isPublic ? 'Entrar' : null,
                trailingNote: g.isPublic ? null : 'Requiere invitación',
              ),
            ),
          ).toList(),
        ),
      );
    }

    final pinned = _pinnedSection;
    final rest = _messagesSection;

    if (pinned.isEmpty && rest.isEmpty) {
      return Center(
        child: Text(
          _conversations.isEmpty
              ? 'Sin conversaciones. Sigue a alguien y envía un mensaje.'
              : 'No hay resultados',
          textAlign: TextAlign.center,
          style: const TextStyle(color: KairoColors.darkTextSecondary),
        ),
      );
    }

    return RefreshIndicator(
      color: KairoColors.primary500,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          if (pinned.isNotEmpty) ...[
            const _SectionLabel('FIJADOS', color: Color(0xFFFBBF24)),
            ...pinned.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ConversationTile(
                  conversation: c,
                  pinned: true,
                  onTap: () => _openThread(c),
                  onPin: () => _setPin(c, pin: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (rest.isNotEmpty) ...[
            const _SectionLabel('MENSAJES', color: KairoColors.primary400),
            ...rest.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ConversationTile(
                  conversation: c,
                  pinned: false,
                  onTap: () => _openThread(c),
                  onPin: () => _setPin(c, pin: true),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _composeNewMessage() async {
    final user = await showNewMessageSheet(context);
    if (user == null || !mounted) return;
    context.push('/chat/${user.id}?name=${Uri.encodeComponent(user.displayName)}');
  }

  void _openThread(Conversation c) {
    context.push(
      '/chat/${c.otherUser.id}?name=${Uri.encodeComponent(c.otherUser.displayName)}',
    );
  }

  void _openGroup(ChatGroup g) {
    context.push(
      '/chat/group/${g.id}?name=${Uri.encodeComponent(g.name)}',
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unreadCount,
    required this.onCompose,
    this.showCreateGroup = false,
  });

  final int unreadCount;
  final VoidCallback onCompose;
  final bool showCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mensajes',
                  style: TextStyle(
                    color: KairoColors.darkText,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unreadCount == 1 ? '1 sin leer' : '$unreadCount sin leer',
                  style: const TextStyle(
                    color: KairoColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCompose,
              borderRadius: BorderRadius.circular(12),
              child: Tooltip(
                message: showCreateGroup ? 'Crear grupo' : 'Nuevo mensaje',
                child: Ink(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: KairoColors.buttonGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    showCreateGroup ? Icons.group_add : Icons.edit_square,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
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
        hintText: 'Buscar conversaciones...',
        hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 15),
        prefixIcon: const Icon(Icons.search, color: KairoColors.darkTextSecondary),
        filled: true,
        fillColor: KairoColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Filtros en una sola fila horizontal: Todos / No leídos / Fijados / Grupos.
class _FilterBlock extends StatelessWidget {
  const _FilterBlock({
    required this.filter,
    required this.allCount,
    required this.unreadCount,
    required this.pinnedCount,
    required this.groupsCount,
    required this.onChanged,
  });

  final _ChatFilter filter;
  final int allCount;
  final int unreadCount;
  final int pinnedCount;
  final int groupsCount;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _FilterChip(
              label: 'Todos',
              count: allCount,
              selected: filter == _ChatFilter.all,
              onTap: () => onChanged(_ChatFilter.all),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'No leídos',
              count: unreadCount,
              selected: filter == _ChatFilter.unread,
              showDot: true,
              onTap: () => onChanged(_ChatFilter.unread),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Fijados',
              count: pinnedCount,
              selected: filter == _ChatFilter.pinned,
              icon: Icons.push_pin,
              onTap: () => onChanged(_ChatFilter.pinned),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Grupos',
              count: groupsCount,
              selected: filter == _ChatFilter.groups,
              icon: Icons.groups,
              onTap: () => onChanged(_ChatFilter.groups),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.showDot = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? null : KairoColors.darkCard;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? KairoColors.buttonGradient : null,
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDot) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: KairoColors.primary400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : KairoColors.darkTextSecondary,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : KairoColors.darkTextSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : KairoColors.primary300,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.pinned,
    required this.onTap,
    required this.onPin,
  });

  final Conversation conversation;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final preview = c.lastMessage.mediaUrl != null && c.lastMessage.content.isEmpty
        ? (c.lastMessage.isVideo ? 'Historia' : 'Foto')
        : c.lastMessage.content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  KairoAvatar(
                    imageUrl: c.otherUser.image,
                    name: c.otherUser.displayName,
                    size: 54,
                  ),
                  if (pinned)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBBF24),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.push_pin, size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.otherUser.displayName,
                      style: const TextStyle(
                        color: KairoColors.darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: const TextStyle(
                        color: KairoColors.darkTextSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _compactTime(c.lastMessage.createdAt),
                    style: const TextStyle(
                      color: KairoColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (c.unreadCount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: KairoColors.primary500,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${c.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: KairoColors.darkTextSecondary, size: 20),
                color: KairoColors.darkCard,
                onSelected: (value) {
                  if (value == 'pin') onPin();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          pinned ? Icons.push_pin_outlined : Icons.push_pin,
                          color: KairoColors.darkText,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          pinned ? 'Quitar fijado' : 'Fijar chat',
                          style: const TextStyle(color: KairoColors.darkText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _compactTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}sem';
  }
}

class _GroupsSectionTabs extends StatelessWidget {
  const _GroupsSectionTabs({required this.section, required this.onChanged});

  final _GroupsSection section;
  final ValueChanged<_GroupsSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SectionTab(
            label: 'Mis grupos',
            selected: section == _GroupsSection.mine,
            onTap: () => onChanged(_GroupsSection.mine),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SectionTab(
            label: 'Todos',
            selected: section == _GroupsSection.all,
            onTap: () => onChanged(_GroupsSection.all),
          ),
        ),
      ],
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? KairoColors.buttonGradient : null,
            color: selected ? null : KairoColors.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : KairoColors.darkTextSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.onTap,
    this.actionLabel,
    this.trailingNote,
  });

  final ChatGroup group;
  final VoidCallback? onTap;
  final String? actionLabel;
  final String? trailingNote;

  @override
  Widget build(BuildContext context) {
    final preview = group.lastMessagePreview ?? 'Sin mensajes aún';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: KairoColors.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        color: KairoColors.darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: const TextStyle(
                        color: KairoColors.darkTextSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${group.memberCount} miembros',
                          style: const TextStyle(
                            color: KairoColors.primary400,
                            fontSize: 11,
                          ),
                        ),
                        if (group.isPublic) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KairoColors.primary500.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Público',
                              style: TextStyle(color: KairoColors.primary400, fontSize: 10),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KairoColors.darkHover,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Privado',
                              style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onTap,
                  child: Text(actionLabel!),
                )
              else if (trailingNote != null)
                Text(
                  trailingNote!,
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
                  textAlign: TextAlign.right,
                )
              else if (group.lastMessageAt != null)
                Text(
                  _ConversationTile._compactTime(group.lastMessageAt!),
                  style: const TextStyle(
                    color: KairoColors.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
