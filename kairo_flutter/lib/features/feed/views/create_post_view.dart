import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/auth/widgets/gradient_button.dart';
import '../../../features/auth/widgets/kairo_alert.dart';
import '../../posts/providers/posts_provider.dart';
import '../widgets/media_review_view.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _content = TextEditingController();
  PostKind _postKind = PostKind.post;
  bool _submitting = false;
  String? _error;
  final List<DraftMedia> _files = [];

  static const _kinds = [
    (PostKind.post, 'Publicación', 'Comparte lo que quieras con la comunidad.'),
    (PostKind.testimony, 'Testimonio', 'Historias de fe y vida.'),
    (PostKind.prayer, 'Petición de oración', 'Pide oración por una situación.'),
  ];

  bool get _isPrayer => _postKind == PostKind.prayer;

  @override
  void initState() {
    super.initState();
    _content.addListener(() {
      if (_files.isNotEmpty && mounted) setState(() {});
    });
  }

  String? get _authorName {
    final user = AuthService().currentUser;
    final metaName = user?.userMetadata?['name'] as String?;
    if (metaName != null && metaName.trim().isNotEmpty) return metaName.trim();
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Tú';
  }

  String? get _authorImage {
    final meta = AuthService().currentUser?.userMetadata;
    return (meta?['image'] ?? meta?['avatar_url']) as String?;
  }

  void _selectKind(PostKind kind) {
    setState(() {
      _postKind = kind;
      _error = null;
      if (kind == PostKind.prayer) _files.clear();
    });
  }

  Future<void> _reviewAndAdd(List<DraftMedia> incoming, {bool replace = false}) async {
    if (incoming.isEmpty || !mounted) return;
    final confirmed = await showMediaReview(
      context: context,
      items: incoming,
      postKind: _postKind,
      caption: _content.text,
      authorName: _authorName,
      authorImage: _authorImage,
    );
    if (!mounted || confirmed == null) return;
    setState(() {
      if (replace) {
        _files
          ..clear()
          ..addAll(confirmed);
      } else {
        final room = 12 - _files.length;
        _files.addAll(confirmed.take(room));
      }
    });
  }

  Future<void> _pickImages() async {
    if (_isPrayer) return;
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty || !mounted) return;
    final drafts = <DraftMedia>[];
    for (final img in images) {
      if (_files.length + drafts.length >= 12) break;
      final bytes = await img.readAsBytes();
      drafts.add(DraftMedia(bytes: bytes, name: img.name, mime: 'image/jpeg', path: img.path));
    }
    await _reviewAndAdd(drafts);
  }

  Future<void> _pickVideo() async {
    if (_isPrayer) return;
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (video == null || _files.length >= 12 || !mounted) return;
    final bytes = await video.readAsBytes();
    await _reviewAndAdd([
      DraftMedia(bytes: bytes, name: video.name, mime: 'video/mp4', path: video.path),
    ]);
  }

  Future<void> _openExistingReview() async {
    if (_files.isEmpty) return;
    await _reviewAndAdd(List<DraftMedia>.from(_files), replace: true);
  }

  Future<void> _submit() async {
    if (!AuthService().isSignedIn) {
      context.go('/auth/signin');
      return;
    }
    final trimmed = _content.text.trim();
    if (_isPrayer) {
      if (trimmed.isEmpty) {
        setState(() => _error = 'Escribe tu petición de oración.');
        return;
      }
    } else if (trimmed.isEmpty && _files.isEmpty) {
      setState(() => _error = 'Escribe algo o elige fotos o videos.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await context.read<PostsProvider>().createPost(
            content: trimmed.isEmpty ? ' ' : trimmed,
            postKind: _postKind,
            files: _files.isEmpty ? null : [for (final f in _files) f.asUpload],
          );
      if (!mounted) return;
      context.go('/feed');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/feed');
            }
          },
        ),
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
                  onTap: () => _selectKind(k.$1),
                )),
            const SizedBox(height: 20),
            TextField(
              controller: _content,
              maxLines: 6,
              style: const TextStyle(color: KairoColors.darkText),
              decoration: InputDecoration(
                hintText: _isPrayer ? 'Escribe tu petición de oración...' : '¿Qué quieres compartir?',
                hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                filled: true,
                fillColor: KairoColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (!_isPrayer) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting || _files.length >= 12 ? null : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text('Fotos (${_files.where((f) => !f.isVideo).length}/12)'),
                      style: OutlinedButton.styleFrom(foregroundColor: KairoColors.primary400, side: BorderSide.none, backgroundColor: KairoColors.darkCard),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting || _files.length >= 12 ? null : _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video'),
                      style: OutlinedButton.styleFrom(foregroundColor: KairoColors.primary400, side: BorderSide.none, backgroundColor: KairoColors.darkCard),
                    ),
                  ),
                ],
              ),
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Así queda tu publicación',
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _ComposePreview(
                  files: _files,
                  caption: _content.text,
                  postKind: _postKind,
                  authorName: _authorName ?? 'Tú',
                  authorImage: _authorImage,
                  onOpen: _openExistingReview,
                  onRemove: (i) => setState(() => _files.removeAt(i)),
                ),
              ],
            ],
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

class _ComposePreview extends StatelessWidget {
  const _ComposePreview({
    required this.files,
    required this.caption,
    required this.postKind,
    required this.authorName,
    required this.authorImage,
    required this.onOpen,
    required this.onRemove,
  });

  final List<DraftMedia> files;
  final String caption;
  final PostKind postKind;
  final String authorName;
  final String? authorImage;
  final VoidCallback onOpen;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final text = caption.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (postKind == PostKind.testimony)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Testimonio', style: TextStyle(color: KairoColors.primary400, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            Row(
              children: [
                KairoAvatar(imageUrl: authorImage, name: authorName, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                TextButton(
                  onPressed: onOpen,
                  child: const Text('Editar', style: TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: files.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final file = files[i];
                  return GestureDetector(
                    onTap: onOpen,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: file.isVideo
                                ? const ColoredBox(
                                    color: Color(0xFF111111),
                                    child: Center(child: Icon(Icons.videocam, color: Colors.white70)),
                                  )
                                : Image.memory(file.bytes, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onRemove(i),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _kindIcon(PostKind kind, {required Color color}) {
  final asset = switch (kind) {
    PostKind.testimony => 'assets/icons/testimony.png',
    PostKind.prayer => 'assets/icons/prayer.png',
    PostKind.post => 'assets/icons/publication.png',
  };
  return Image.asset(
    asset,
    width: 24,
    height: 24,
    color: color,
    colorBlendMode: BlendMode.srcIn,
  );
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
        ),
        child: Row(
          children: [
            _kindIcon(
              kind,
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
