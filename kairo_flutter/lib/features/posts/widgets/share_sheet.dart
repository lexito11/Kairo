import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../users/services/users_repository.dart';

String buildPostShareLink(String postId) {
  final origin = Uri.base.origin;
  if (origin.isNotEmpty && origin != 'about:blank') {
    return '$origin/feed?post=$postId';
  }
  return 'kairo://post/$postId';
}

String buildPostShareText({String? preview, required String postId}) {
  final link = buildPostShareLink(postId);
  final excerpt = preview?.trim();
  if (excerpt != null && excerpt.isNotEmpty) {
    return '$excerpt\n\n$link';
  }
  return 'Mira esta publicación en KAIRO\n$link';
}

class _SharePlatformOption {
  const _SharePlatformOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.uriBuilder,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Uri Function(String text, String link) uriBuilder;
}

const _platforms = [
  _SharePlatformOption(
    label: 'WhatsApp',
    icon: Icons.chat_bubble_outline,
    color: Color(0xFF25D366),
    uriBuilder: _whatsappUri,
  ),
  _SharePlatformOption(
    label: 'Telegram',
    icon: Icons.send_outlined,
    color: Color(0xFF229ED9),
    uriBuilder: _telegramUri,
  ),
  _SharePlatformOption(
    label: 'Facebook',
    icon: Icons.facebook,
    color: Color(0xFF1877F2),
    uriBuilder: _facebookUri,
  ),
  _SharePlatformOption(
    label: 'X',
    icon: Icons.tag,
    color: Color(0xFF000000),
    uriBuilder: _xUri,
  ),
  _SharePlatformOption(
    label: 'Correo',
    icon: Icons.email_outlined,
    color: Color(0xFFEA4335),
    uriBuilder: _emailUri,
  ),
];

Uri _whatsappUri(String text, String link) =>
    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

Uri _telegramUri(String text, String link) => Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(text)}',
    );

Uri _facebookUri(String text, String link) =>
    Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}');

Uri _xUri(String text, String link) => Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(link)}',
    );

Uri _emailUri(String text, String link) => Uri.parse(
      'mailto:?subject=${Uri.encodeComponent('Publicación en KAIRO')}&body=${Uri.encodeComponent(text)}',
    );

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
  bool _loadingContacts = true;

  String get _shareText => buildPostShareText(preview: widget.postPreview, postId: widget.postId);
  String get _shareLink => buildPostShareLink(widget.postId);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _repo.getContacts();
      if (mounted) setState(() { _contacts = contacts; _loadingContacts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _launchExternal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('No se pudo abrir la aplicación');
  }

  Future<void> _shareViaPlatform(_SharePlatformOption platform) async {
    try {
      await _launchExternal(platform.uriBuilder(_shareText, _shareLink));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _toast('No se pudo compartir en ${platform.label}');
    }
  }

  Future<void> _shareNative() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _shareText, subject: 'KAIRO'));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _shareText));
      if (mounted) {
        Navigator.pop(context);
        _toast('Enlace copiado');
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shareText));
    Navigator.pop(context);
    _toast('Enlace copiado');
  }

  void _shareToContact(KairoUser user) {
    Clipboard.setData(ClipboardData(text: _shareText));
    Navigator.pop(context);
    _toast('Enlace copiado para ${user.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      decoration: const BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: KairoColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Compartir',
            style: TextStyle(color: KairoColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (widget.postPreview != null && widget.postPreview!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.postPreview!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Redes y mensajería',
            style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _platforms.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                if (i == _platforms.length) {
                  return _SharePlatformButton(
                    label: 'Más',
                    icon: Icons.ios_share,
                    color: KairoColors.primary500,
                    onTap: _shareNative,
                  );
                }
                final platform = _platforms[i];
                return _SharePlatformButton(
                  label: platform.label,
                  icon: platform.icon,
                  color: platform.color,
                  onTap: () => _shareViaPlatform(platform),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'En KAIRO',
            style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loadingContacts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
            )
          else if (_contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Agrega contactos siguiendo personas para compartir',
                textAlign: TextAlign.center,
                style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
              ),
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
                    onTap: () => _shareToContact(u),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          KairoAvatar(imageUrl: u.image, name: u.displayName, size: 56),
                          const SizedBox(height: 6),
                          Text(
                            u.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _copyLink,
            icon: const Icon(Icons.link),
            label: const Text('Copiar enlace'),
            style: OutlinedButton.styleFrom(
              foregroundColor: KairoColors.primary400,
              side: const BorderSide(color: KairoColors.darkBorder),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _SharePlatformButton extends StatelessWidget {
  const _SharePlatformButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
