import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/models/profile_moment.dart';
import '../../../core/models/story.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../stories/services/stories_repository.dart';
import '../../stories/widgets/story_viewer.dart';
import '../services/moments_repository.dart';
import '../views/cover_crop_view.dart';

class MomentsStrip extends StatefulWidget {
  const MomentsStrip({
    super.key,
    required this.userId,
    required this.isOwner,
    required this.author,
  });

  final String userId;
  final bool isOwner;
  final KairoUser author;

  @override
  State<MomentsStrip> createState() => _MomentsStripState();
}

class _MomentsStripState extends State<MomentsStrip> {
  final _repo = MomentsRepository();
  List<ProfileMoment> _moments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MomentsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    try {
      final moments = await _repo.list(widget.userId);
      if (!mounted) return;
      setState(() {
        _moments = moments.where((m) => m.items.isNotEmpty || widget.isOwner).toList();
      });
    } catch (_) {}
  }

  Future<bool> _edit(ProfileMoment moment) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KairoColors.darkCard,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MomentEditorSheet(existing: moment),
    );
    if (ok == true) await _load();
    return ok == true;
  }

  void _openMoment(ProfileMoment moment) {
    if (moment.items.isEmpty) return;
    final withMedia = _moments.where((m) => m.items.isNotEmpty).toList();
    final groupIndex = withMedia.indexWhere((m) => m.id == moment.id);
    if (groupIndex < 0) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StoryViewer(
              groups: [for (final m in withMedia) m.toStoryGroup(widget.author)],
              initialGroupIndex: groupIndex,
              moment: moment,
              canManageMoment: widget.isOwner,
              onEditMoment: () => _edit(moment),
              onDeleteMoment: () => _repo.delete(moment.id),
            ),
          ),
        )
        .then((_) => _load());
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KairoColors.darkCard,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _MomentEditorSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOwner && _moments.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = _moments.length + (widget.isOwner ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Momentos',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (widget.isOwner && i == 0) {
                return _MomentTile(
                  create: true,
                  label: 'Crear momento',
                  onTap: _create,
                );
              }
              final moment = _moments[widget.isOwner ? i - 1 : i];
              return _MomentTile(
                label: moment.title,
                style: moment.style,
                coverUrl: moment.coverImageUrl,
                onTap: () => _openMoment(moment),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MomentTile extends StatelessWidget {
  const _MomentTile({
    required this.label,
    required this.onTap,
    this.style,
    this.coverUrl,
    this.create = false,
  });

  final String label;
  final VoidCallback onTap;
  final MomentIconStyle? style;
  final String? coverUrl;
  final bool create;

  static const _size = 82.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: _size,
              height: _size,
              child: create
                  ? CustomPaint(
                      painter: _DashedRRectPainter(),
                      child: const SizedBox.expand(
                        child: Center(
                          child: Icon(Icons.add, color: KairoColors.darkTextSecondary, size: 26),
                        ),
                      ),
                    )
                  : _cover(),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover() {
    final photo = coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFF1C2430),
        child: photo == null || photo.isEmpty
            ? _iconFallback()
            : CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                width: _size,
                height: _size,
                placeholder: (_, __) => _iconFallback(),
                errorWidget: (_, __, ___) => _iconFallback(),
              ),
      ),
    );
  }

  Widget _iconFallback() {
    final color = style?.color ?? KairoColors.darkTextSecondary;
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.0),
            ],
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16),
          ],
        ),
        child: Icon(style?.icon ?? Icons.star, color: color, size: 26),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(22),
    );
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MomentEditorSheet extends StatefulWidget {
  const _MomentEditorSheet({this.existing});

  final ProfileMoment? existing;

  @override
  State<_MomentEditorSheet> createState() => _MomentEditorSheetState();
}

class _MomentEditorSheetState extends State<_MomentEditorSheet> {
  final _repo = MomentsRepository();
  final _storiesRepo = StoriesRepository();
  final _title = TextEditingController();
  String _iconId = MomentIconStyle.catalog.first.id;
  String? _coverImageUrl;
  List<MomentItem> _items = [];
  List<Story> _stories = const [];
  final Set<String> _pickedStoryIds = {};
  bool _saving = false;
  bool _loadingStories = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _iconId = existing.iconId;
      _coverImageUrl = existing.coverImageUrl;
      _items = List.of(existing.items);
      _pickedStoryIds.addAll(
        existing.items.map((e) => e.storyId).whereType<String>(),
      );
    }
    _loadStories();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadStories() async {
    final stories = await _storiesRepo.fetchMyHighlightStories();
    if (!mounted) return;
    setState(() {
      _stories = stories;
      _loadingStories = false;
    });
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null || !mounted) return;
    final original = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await showMomentCoverCropper(context, original);
    if (cropped == null || cropped.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      final url = await _repo.uploadCover(bytes: cropped, fileName: 'moment-cover.png');
      if (!mounted) return;
      setState(() => _coverImageUrl = url);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<MomentItem> _composeItems() {
    final kept = [
      for (final item in _items)
        if (item.storyId != null && _pickedStoryIds.contains(item.storyId)) item,
    ];
    final existingStoryIds = kept.map((e) => e.storyId).whereType<String>().toSet();
    final added = _stories
        .where((s) => _pickedStoryIds.contains(s.id) && !existingStoryIds.contains(s.id))
        .map(
          (s) => _repo.itemFromStory(
            storyId: s.id,
            mediaUrl: s.mediaUrl,
            mediaType: s.mediaType,
          ),
        );
    return [...kept, ...added];
  }

  Future<void> _save() async {
    final items = _composeItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige al menos una historia publicada')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await _repo.create(
          title: _title.text,
          iconId: _iconId,
          items: items,
          coverImageUrl: _coverImageUrl,
        );
      } else {
        await _repo.updateMeta(
          momentId: existing.id,
          title: _title.text,
          iconId: _iconId,
          coverImageUrl: _coverImageUrl,
          clearCover: _coverImageUrl == null || _coverImageUrl!.isEmpty,
        );
        await _repo.replaceItems(existing.id, items);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'Nuevo momento' : 'Editar momento',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Nombre del momento',
                hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
                filled: true,
                fillColor: KairoColors.darkHover,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Portada', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in MomentIconStyle.catalog)
                  GestureDetector(
                    onTap: () => setState(() {
                      _iconId = icon.id;
                      _coverImageUrl = null;
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2430),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _coverImageUrl == null && _iconId == icon.id
                              ? icon.color
                              : KairoColors.darkBorder,
                          width: _coverImageUrl == null && _iconId == icon.id ? 2 : 1,
                        ),
                      ),
                      child: Icon(icon.icon, color: icon.color, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickCover,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_coverImageUrl == null ? 'Portada de galería' : 'Cambiar portada de galería'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KairoColors.primary400,
                side: const BorderSide(color: KairoColors.darkBorder),
              ),
            ),
            if (_coverImageUrl != null) ...[
              const SizedBox(height: 12),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: CachedNetworkImage(
                    imageUrl: _coverImageUrl!,
                    width: _MomentTile._size,
                    height: _MomentTile._size,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'El contenido del momento son solo historias que hayas publicado (activas o del archivo).',
              style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (_loadingStories)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(color: KairoColors.primary500, strokeWidth: 2)),
              )
            else if (_stories.isEmpty)
              const Text(
                'No hay historias guardadas. Publica una historia y activa “Guardar historias” en Ajustes.',
                style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
              )
            else ...[
              if (_stories.any((s) => !s.isExpired)) ...[
                const Text('Activas', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _StoryPickRow(
                  stories: _stories.where((s) => !s.isExpired).toList(),
                  selectedIds: _pickedStoryIds,
                  onToggle: _toggleStory,
                ),
                const SizedBox(height: 12),
              ],
              if (_stories.any((s) => s.isExpired)) ...[
                const Text('Archivo', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _StoryPickRow(
                  stories: _stories.where((s) => s.isExpired).toList(),
                  selectedIds: _pickedStoryIds,
                  onToggle: _toggleStory,
                ),
              ],
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: KairoColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.existing == null ? 'Crear momento' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStory(String id) {
    setState(() {
      if (_pickedStoryIds.contains(id)) {
        _pickedStoryIds.remove(id);
      } else {
        _pickedStoryIds.add(id);
      }
    });
  }
}

class _StoryPickRow extends StatelessWidget {
  const _StoryPickRow({
    required this.stories,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Story> stories;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final story = stories[i];
          final selected = selectedIds.contains(story.id);
          return GestureDetector(
            onTap: () => onToggle(story.id),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? KairoColors.primary400 : KairoColors.darkBorder,
                  width: 2,
                ),
                image: DecorationImage(
                  image: NetworkImage(story.mediaUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: selected
                  ? const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.check_circle, color: KairoColors.primary400, size: 18),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
