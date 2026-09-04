import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../messages/services/messages_repository.dart';
import '../../users/services/users_repository.dart';

String buildAppShareLink(String pathAndQuery) {
  final origin = Uri.base.origin;
  if (origin.isNotEmpty && origin != 'about:blank') {
    return '$origin$pathAndQuery';
  }
  return 'kairo:/$pathAndQuery';
}

String buildPostShareLink(String postId) => buildAppShareLink('/feed?post=$postId');

String buildProfileShareLink(String userId) => buildAppShareLink('/profile?userId=$userId');

String buildPostShareText({String? preview, required String postId}) {
  final link = buildPostShareLink(postId);
  final excerpt = preview?.trim();
  if (excerpt != null && excerpt.isNotEmpty) {
    return '$excerpt\n\n$link';
  }
  return 'Mira esta publicación en KAIRO\n$link';
}

String buildProfileShareText(KairoUser user) {
  final handle = user.username != null && user.username!.trim().isNotEmpty
      ? ' (@${user.username!.trim()})'
      : '';
  return 'Mira el perfil de ${user.displayName}$handle en KAIRO\n${buildProfileShareLink(user.id)}';
}

Future<void> showKairoShareSheet(
  BuildContext context, {
  String? postId,
  String? postPreview,
  String? shareText,
  String? shareLink,
  String title = 'Compartir',
  String emailSubject = 'KAIRO',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShareSheet(
      postId: postId,
      postPreview: postPreview,
      shareText: shareText,
      shareLink: shareLink,
      title: title,
      emailSubject: emailSubject,
    ),
  );
}

class _SharePlatformOption {
  const _SharePlatformOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.uriBuilder,
    this.copyThenOpen = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Uri Function(String text, String link) uriBuilder;
  final bool copyThenOpen;
}

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

Uri _instagramUri(String text, String link) => Uri.parse('https://www.instagram.com/');

class ShareSheet extends StatefulWidget {
  const ShareSheet({
    super.key,
    this.postId,
    this.postPreview,
    this.shareText,
    this.shareLink,
    this.title = 'Compartir',
    this.emailSubject = 'KAIRO',
  });

  final String? postId;
  final String? postPreview;
  final String? shareText;
  final String? shareLink;
  final String title;
  final String emailSubject;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _repo = UsersRepository();
  final _messages = MessagesRepository();
  List<KairoUser> _contacts = [];
  bool _loadingContacts = true;
  String? _sendingToId;

  String get _shareLink {
    final custom = widget.shareLink?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final postId = widget.postId;
    if (postId != null) return buildPostShareLink(postId);
    return '';
  }

  String get _shareText {
    final custom = widget.shareText?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final postId = widget.postId;
    if (postId != null) return buildPostShareText(preview: widget.postPreview, postId: postId);
    return _shareLink;
  }

  List<_SharePlatformOption> get _platforms => [
        const _SharePlatformOption(
          label: 'WhatsApp',
          icon: Icons.chat_bubble_outline,
          color: Color(0xFF25D366),
          uriBuilder: _whatsappUri,
        ),
        const _SharePlatformOption(
          label: 'Telegram',
          icon: Icons.send_outlined,
          color: Color(0xFF229ED9),
          uriBuilder: _telegramUri,
        ),
        const _SharePlatformOption(
          label: 'Facebook',
          icon: Icons.facebook,
          color: Color(0xFF1877F2),
          uriBuilder: _facebookUri,
        ),
        const _SharePlatformOption(
          label: 'Instagram',
          icon: Icons.camera_alt_outlined,
          color: Color(0xFFE4405F),
          uriBuilder: _instagramUri,
          copyThenOpen: true,
        ),
        const _SharePlatformOption(
          label: 'X',
          icon: Icons.tag,
          color: Color(0xFF000000),
          uriBuilder: _xUri,
        ),
        _SharePlatformOption(
          label: 'Correo',
          icon: Icons.email_outlined,
          color: const Color(0xFFEA4335),
          uriBuilder: (text, link) => Uri.parse(
            'mailto:?subject=${Uri.encodeComponent(widget.emailSubject)}&body=${Uri.encodeComponent(text)}',
          ),
        ),
      ];

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
      if (platform.copyThenOpen) {
        await Clipboard.setData(ClipboardData(text: _shareLink.isNotEmpty ? _shareLink : _shareText));
        await _launchExternal(platform.uriBuilder(_shareText, _shareLink));
        if (mounted) {
          Navigator.pop(context);
          _toast('Enlace copiado. Pégalo en ${platform.label}');
        }
        return;
      }
      await _launchExternal(platform.uriBuilder(_shareText, _shareLink));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _toast('No se pudo compartir en ${platform.label}');
    }
  }

  Future<void> _shareNative() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _shareText, subject: widget.emailSubject));
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
    Clipboard.setData(ClipboardData(text: _shareLink.isNotEmpty ? _shareLink : _shareText));
    Navigator.pop(context);
    _toast('Enlace copiado');
  }

  Future<void> _shareToContact(KairoUser user) async {
    if (_sendingToId != null) return;
    setState(() => _sendingToId = user.id);
    try {
      await _messages.sendMessage(user.id, _shareText);
      if (!mounted) return;
      Navigator.pop(context);
      _toast('Enviado a ${user.displayName}');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _shareText));
      if (!mounted) return;
      Navigator.pop(context);
      _toast('No se pudo enviar. Enlace copiado para ${user.displayName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final preview = widget.postPreview?.trim();
    final platforms = _platforms;

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
          Text(
            widget.title,
            style: const TextStyle(color: KairoColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (preview != null && preview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              preview,
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
              itemCount: platforms.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                if (i == platforms.length) {
                  return _SharePlatformButton(
                    label: 'Más',
                    icon: Icons.ios_share,
                    color: KairoColors.primary500,
                    onTap: _shareNative,
                  );
                }
                final platform = platforms[i];
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
                  final sending = _sendingToId == u.id;
                  return GestureDetector(
                    onTap: sending ? null : () => _shareToContact(u),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              KairoAvatar(imageUrl: u.image, name: u.displayName, size: 56),
                              if (sending)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
                                ),
                            ],
                          ),
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
