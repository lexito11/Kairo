import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../users/services/users_repository.dart';

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.postId, this.postPreview});

  final String postId;
  final String? postPreview;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _repo = UsersRepository();
  List<KairoUser> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await _repo.getContacts();
      if (mounted) setState(() { _contacts = contacts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shareTo(KairoUser user) {
    final link = 'kairo://post/${widget.postId}';
    Clipboard.setData(ClipboardData(text: link));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Compartir', style: TextStyle(color: KairoColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
          if (widget.postPreview != null) ...[
            const SizedBox(height: 8),
            Text(widget.postPreview!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)))
          else if (_contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Agrega contactos siguiendo personas para compartir', textAlign: TextAlign.center, style: TextStyle(color: KairoColors.darkTextSecondary)),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) {
                  final u = _contacts[i];
                  return GestureDetector(
                    onTap: () {
                      _shareTo(u);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enlace copiado para ${u.displayName}')));
                    },
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          KairoAvatar(imageUrl: u.image, name: u.displayName, size: 56),
                          const SizedBox(height: 6),
                          Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'kairo://post/${widget.postId}'));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
            },
            icon: const Icon(Icons.link),
            label: const Text('Copiar enlace'),
            style: OutlinedButton.styleFrom(foregroundColor: KairoColors.primary400, side: const BorderSide(color: KairoColors.darkBorder)),
          ),
        ],
      ),
    );
  }
}
