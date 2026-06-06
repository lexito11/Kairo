import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/story.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../features/auth/services/auth_service.dart';
import '../services/stories_repository.dart';
import 'story_viewer.dart';

class StoriesStrip extends StatefulWidget {
  const StoriesStrip({super.key});

  @override
  State<StoriesStrip> createState() => _StoriesStripState();
}

class _StoriesStripState extends State<StoriesStrip> {
  final _repo = StoriesRepository();
  List<StoryGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService().isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final groups = await _repo.fetchStoryGroups();
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStory() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _repo.publishStory(bytes: bytes, fileName: file.name, mimeType: 'image/jpeg');
    await _load();
  }

  void _openGroup(StoryGroup group, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewer(groups: _groups, initialGroupIndex: _groups.indexOf(group), initialStoryIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: KairoColors.primary500, strokeWidth: 2)));
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (AuthService().isSignedIn)
            _StoryBubble(
              label: 'Tu historia',
              isAdd: true,
              onTap: _addStory,
            ),
          ..._groups.map((g) {
            final isMine = g.author.id == AuthService().currentUser?.id;
            return _StoryBubble(
              label: isMine ? 'Tu historia' : g.author.displayName,
              imageUrl: g.author.image,
              name: g.author.displayName,
              hasGradient: !isMine,
              onTap: () => _openGroup(g, 0),
            );
          }),
        ],
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    this.isAdd = false,
    this.hasGradient = false,
    this.imageUrl,
    this.name,
    this.onTap,
  });

  final String label;
  final bool isAdd;
  final bool hasGradient;
  final String? imageUrl;
  final String? name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: hasGradient ? const EdgeInsets.all(2) : null,
              decoration: hasGradient
                  ? const BoxDecoration(shape: BoxShape.circle, gradient: KairoColors.logoGradient)
                  : null,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isAdd ? Border.all(color: KairoColors.darkBorder, width: 2) : null,
                  color: isAdd ? KairoColors.darkCard : KairoColors.darkHover,
                ),
                clipBehavior: Clip.antiAlias,
                child: isAdd
                    ? const Icon(Icons.add, color: KairoColors.primary500)
                    : KairoAvatar(imageUrl: imageUrl, name: name, size: 64),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
