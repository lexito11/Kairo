import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/auth/widgets/gradient_button.dart';
import '../../../features/auth/widgets/kairo_alert.dart';
import '../../posts/providers/posts_provider.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _content = TextEditingController();
  PostKind _postKind = PostKind.post;
  bool _isAnonymous = false;
  bool _submitting = false;
  String? _error;
  final List<({Uint8List bytes, String name, String mime})> _files = [];

  static const _kinds = [
    (PostKind.post, 'Publicación', 'Comparte lo que quieras con la comunidad.'),
    (PostKind.testimony, 'Testimonio', 'Historias de fe y vida.'),
    (PostKind.prayer, 'Petición de oración', 'Pide oración por una situación.'),
  ];

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    for (final img in images) {
      if (_files.length >= 12) break;
      final bytes = await img.readAsBytes();
      _files.add((bytes: bytes, name: img.name, mime: 'image/jpeg'));
    }
    setState(() {});
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (video == null || _files.length >= 12) return;
    final bytes = await video.readAsBytes();
    _files.add((bytes: bytes, name: video.name, mime: 'video/mp4'));
    setState(() {});
  }

  Future<void> _submit() async {
    if (!AuthService().isSignedIn) {
      context.go('/auth/signin');
      return;
    }
    final trimmed = _content.text.trim();
    if (trimmed.isEmpty && _files.isEmpty) {
      setState(() => _error = 'Escribe algo o elige fotos o videos.');
      return;
    }
    setState(() { _error = null; _submitting = true; });
    try {
      final post = await context.read<PostsProvider>().createPost(
            content: trimmed.isEmpty ? ' ' : trimmed,
            postKind: _postKind,
            isAnonymous: _isAnonymous,
            files: _files.isEmpty ? null : _files,
          );
      if (!mounted) return;
      if (post.isAnonymous) {
        context.go('/profile');
      } else {
        context.go('/feed');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Nueva publicación', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) KairoAlert(message: _error!, type: KairoAlertType.error),
            const Text('¿Qué vas a publicar?', style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._kinds.map((k) => _KindTile(
                  kind: k.$1,
                  label: k.$2,
                  hint: k.$3,
                  selected: _postKind == k.$1,
                  onTap: () => setState(() => _postKind = k.$1),
                )),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Publicar como anónimo', style: TextStyle(color: KairoColors.darkText)),
              subtitle: const Text('Solo visible en tu perfil > Anónimos', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
              value: _isAnonymous,
              activeThumbColor: KairoColors.primary500,
              onChanged: _submitting ? null : (v) => setState(() => _isAnonymous = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              maxLines: 6,
              style: const TextStyle(color: KairoColors.darkText),
              decoration: InputDecoration(
                hintText: '¿Qué quieres compartir?',
                hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                filled: true,
                fillColor: KairoColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: KairoColors.darkBorder)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text('Fotos (${_files.length}/12)'),
                    style: OutlinedButton.styleFrom(foregroundColor: KairoColors.primary400, side: const BorderSide(color: KairoColors.darkBorder)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                    style: OutlinedButton.styleFrom(foregroundColor: KairoColors.primary400, side: const BorderSide(color: KairoColors.darkBorder)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: _submitting ? 'Publicando...' : 'Publicar',
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({required this.kind, required this.label, required this.hint, required this.selected, required this.onTap});
  final PostKind kind;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? KairoColors.primary500.withValues(alpha: 0.15) : KairoColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? KairoColors.primary500 : KairoColors.darkBorder),
        ),
        child: Row(
          children: [
            Icon(
              kind == PostKind.prayer ? Icons.favorite : kind == PostKind.testimony ? Icons.auto_awesome : Icons.edit,
              color: selected ? KairoColors.primary400 : KairoColors.darkTextSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: selected ? KairoColors.primary400 : KairoColors.darkText, fontWeight: FontWeight.w600)),
                  Text(hint, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: KairoColors.primary500, size: 20),
          ],
        ),
      ),
    );
  }
}
