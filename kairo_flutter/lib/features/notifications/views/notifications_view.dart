import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/group_invite.dart';
import '../../../core/providers/social_summary_provider.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../messages/services/groups_repository.dart';
import '../../users/services/users_repository.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _usersRepo = UsersRepository();
  final _groupsRepo = GroupsRepository();
  List<FollowNotification> _follows = [];
  List<GroupInvite> _invites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final follows = await _usersRepo.getNotifications();
      final invites = await _groupsRepo.fetchPendingInvites();
      await _usersRepo.markNotificationsSeen();
      await _groupsRepo.markInvitesSeen();
      final summary = await _usersRepo.getSocialSummary();
      if (mounted) {
        context.read<SocialSummaryProvider>().update(
              unread: summary.unreadCount,
              friends: summary.friendsCount,
            );
        setState(() {
          _follows = follows;
          _invites = invites;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _followBack(String userId) async {
    await _usersRepo.follow(userId);
    await _load();
  }

  Future<void> _acceptInvite(GroupInvite invite) async {
    try {
      await _groupsRepo.acceptInvite(invite);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      context.push('/chat/group/${invite.groupId}?name=${Uri.encodeComponent(invite.groupName)}');
    } on GroupFullException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo aceptar: $e')),
        );
      }
    }
  }

  Future<void> _rejectInvite(GroupInvite invite) async {
    try {
      await _groupsRepo.rejectInvite(invite.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo rechazar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _follows.isEmpty && _invites.isEmpty;

    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : isEmpty
              ? const Center(
                  child: Text(
                    'No hay notificaciones',
                    style: TextStyle(color: KairoColors.darkTextSecondary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_invites.isNotEmpty) ...[
                      const _SectionTitle('Invitaciones a grupos'),
                      ..._invites.map(_buildInviteCard),
                      if (_follows.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (_follows.isNotEmpty) ...[
                      const _SectionTitle('Personas'),
                      ..._follows.map(_buildFollowCard),
                    ],
                  ],
                ),
    );
  }

  Widget _buildInviteCard(GroupInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: invite.isUnread ? KairoColors.primary500.withValues(alpha: 0.08) : KairoColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KairoColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KairoAvatar(
                imageUrl: invite.inviter.image,
                name: invite.inviter.displayName,
                size: 48,
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
                          TextSpan(
                            text: invite.inviter.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' te invitó a ${invite.groupName}'),
                        ],
                      ),
                    ),
                    Text(
                      formatTimeAgo(invite.createdAt),
                      style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectInvite(invite),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _acceptInvite(invite),
                  style: FilledButton.styleFrom(backgroundColor: KairoColors.primary500),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowCard(FollowNotification n) {
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
                      TextSpan(
                        text: n.follower.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' te agregó'),
                    ],
                  ),
                ),
                Text(
                  formatTimeAgo(n.createdAt),
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
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
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: KairoColors.primary400,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
