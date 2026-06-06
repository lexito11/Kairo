import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../core/models/message.dart';
import '../../messages/services/messages_repository.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _repo = MessagesRepository();
  List<Conversation> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.fetchConversations();
      if (mounted) setState(() { _conversations = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      child: RefreshIndicator(
        color: KairoColors.primary500,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: KairoColors.darkBg,
              title: Text('Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)))
            else if (_conversations.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Sin conversaciones. Sigue a alguien y envía un mensaje.', style: TextStyle(color: KairoColors.darkTextSecondary))),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = _conversations[i];
                    return ListTile(
                      leading: KairoAvatar(imageUrl: c.otherUser.image, name: c.otherUser.displayName, size: 48),
                      title: Text(c.otherUser.displayName, style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w600)),
                      subtitle: Text(c.lastMessage.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KairoColors.darkTextSecondary)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatTimeAgo(c.lastMessage.createdAt), style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                          if (c.unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: KairoColors.primary500, shape: BoxShape.circle),
                              child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => context.push('/chat/${c.otherUser.id}?name=${Uri.encodeComponent(c.otherUser.displayName)}'),
                    );
                  },
                  childCount: _conversations.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
