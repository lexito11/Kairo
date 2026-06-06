import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/social_summary_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../users/services/users_repository.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _repo = UsersRepository();
  List<FollowNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _repo.getNotifications();
      await _repo.markNotificationsSeen();
      final summary = await _repo.getSocialSummary();
      if (mounted) {
        context.read<SocialSummaryProvider>().update(
              unread: summary.unreadCount,
              friends: summary.friendsCount,
            );
        setState(() { _items = items; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _followBack(String userId) async {
    await _repo.follow(userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : _items.isEmpty
              ? const Center(child: Text('No hay notificaciones', style: TextStyle(color: KairoColors.darkTextSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: n.isUnread ? KairoColors.primary500.withValues(alpha: 0.08) : KairoColors.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KairoColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          KairoAvatar(
                            imageUrl: n.follower.image,
                            name: n.follower.displayName,
                            size: 48,
                            onTap: () => context.push('/profile?userId=${n.follower.id}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: KairoColors.darkText, fontSize: 14),
                                    children: [
                                      TextSpan(text: n.follower.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const TextSpan(text: ' te agregó'),
                                    ],
                                  ),
                                ),
                                Text(formatTimeAgo(n.createdAt), style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!n.viewerHasAddedBack)
                            TextButton(
                              onPressed: () => _followBack(n.follower.id),
                              child: const Text('Agregar también'),
                            )
                          else
                            const Text('Agregado', style: TextStyle(color: KairoColors.primary400, fontSize: 13)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
