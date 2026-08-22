import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../services/posts_repository.dart';

class AmenLikersSheet extends StatefulWidget {
  const AmenLikersSheet({super.key, required this.postId});

  final String postId;

  @override
  State<AmenLikersSheet> createState() => _AmenLikersSheetState();
}

class _AmenLikersSheetState extends State<AmenLikersSheet> {
  final _repo = PostsRepository();
  List<KairoUser> _likers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final likers = await _repo.fetchPostLikers(widget.postId);
      if (mounted) setState(() { _likers = likers; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: KairoColors.darkBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Amén',
              style: TextStyle(color: KairoColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
                : _likers.isEmpty
                    ? const Center(
                        child: Text('Nadie ha dado Amén aún', style: TextStyle(color: KairoColors.darkTextSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _likers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: KairoColors.darkBorder),
                        itemBuilder: (_, i) {
                          final user = _likers[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: KairoAvatar(imageUrl: user.image, name: user.displayName, size: 44),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w600),
                            ),
                            subtitle: user.username != null
                                ? Text(user.handle, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13))
                                : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/profile?userId=${user.id}');
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

void showAmenLikersSheet(BuildContext context, String postId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AmenLikersSheet(postId: postId),
  );
}

String amenLikerPublicName(KairoUser user) => user.username ?? user.displayName;
