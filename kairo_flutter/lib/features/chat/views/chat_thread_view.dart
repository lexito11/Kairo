import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/message.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../messages/services/messages_repository.dart';
import '../../users/services/users_repository.dart';

class ChatThreadView extends StatefulWidget {
  const ChatThreadView(
      {super.key, required this.otherUserId, required this.otherUserName});

  final String otherUserId;
  final String otherUserName;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _repo = MessagesRepository();
  final _users = UsersRepository();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  String? _otherImage;
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _loadOtherUser();
    _channel = _repo.subscribeToMessages((msg) {
      if (msg.senderId == widget.otherUserId && mounted) {
        setState(() => _messages = [..._messages, msg]);
        _scrollToEnd();
      }
    });
  }

  Future<void> _loadOtherUser() async {
    try {
      final profile = await _users.getUserProfile(widget.otherUserId);
      if (mounted) setState(() => _otherImage = profile.user.image);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchThread(widget.otherUserId);
      if (mounted)
        setState(() {
          _messages = list;
          _loading = false;
        });
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await _repo.sendMessage(widget.otherUserId, text);
      _controller.clear();
      setState(() => _messages = [..._messages, msg]);
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthService().currentUser?.id;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ThreadHeader(
              name: widget.otherUserName,
              imageUrl: _otherImage,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: KairoColors.primary500))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final mine = myId != null && m.isMine(myId);
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    mine ? KairoColors.buttonGradient : null,
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
                                  if (m.hasMedia)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: m.isVideo
                                            ? Container(
                                                width: 180,
                                                height: 240,
                                                color: Colors.black54,
                                                child: const Center(
                                                  child: Icon(
                                                      Icons.play_circle_fill,
                                                      color: Colors.white,
                                                      size: 48),
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: m.mediaUrl!,
                                                width: 180,
                                                height: 240,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) =>
                                                    const SizedBox(
                                                  width: 180,
                                                  height: 240,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white54),
                                                  ),
                                                ),
                                                errorWidget: (_, __, ___) =>
                                                    const SizedBox(
                                                  width: 180,
                                                  height: 120,
                                                  child: Center(
                                                      child: Icon(
                                                          Icons.broken_image,
                                                          color:
                                                              Colors.white54)),
                                                ),
                                              ),
                                      ),
                                    ),
                                  if (m.content.isNotEmpty)
                                    Text(
                                      m.content,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.35,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeLabel(m.createdAt.toLocal()),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.65),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            _Composer(
              controller: _controller,
              sending: _sending,
              bottomPad: bottomPad,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.name,
    required this.onBack,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
          KairoAvatar(imageUrl: imageUrl, name: name, size: 40),
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
                const Text(
                  'En línea',
                  style: TextStyle(
                      color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: KairoColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KairoColors.darkBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble,
                    color: KairoColors.primary400, size: 18),
                SizedBox(width: 10),
                Icon(Icons.grid_view_rounded,
                    color: KairoColors.darkTextSecondary, size: 18),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert,
                color: KairoColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.bottomPad,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final double bottomPad;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, bottomPad + 10),
      decoration: const BoxDecoration(
        color: KairoColors.darkBg,
        border: Border(top: BorderSide(color: KairoColors.darkBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.image_outlined,
                color: KairoColors.darkTextSecondary),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.mic_none_rounded,
                color: KairoColors.darkTextSecondary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: KairoColors.darkText, fontSize: 15),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle:
                    const TextStyle(color: KairoColors.darkTextSecondary),
                filled: true,
                fillColor: KairoColors.darkCard,
                suffixIcon: const Icon(Icons.sentiment_satisfied_alt_outlined,
                    color: KairoColors.darkTextSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: sending ? null : onSend,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KairoColors.buttonGradient,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
