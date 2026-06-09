import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/story.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../features/auth/services/auth_service.dart';
import '../services/stories_repository.dart';
import 'story_viewer.dart';

/// Tarjetas verticales compactas estilo Facebook Stories.
const _kStoryWidth = 54.0;
const _kStoryHeight = 84.0;
const _kStoryRadius = 10.0;
const _kStripHeight = 96.0;

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
      return const SizedBox(
        height: _kStripHeight,
        child: Center(child: CircularProgressIndicator(color: KairoColors.primary500, strokeWidth: 2)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: _kStripHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
          if (AuthService().isSignedIn)
            _StoryCard(
              label: 'Tu historia',
              isAdd: true,
              onTap: _addStory,
            ),
          ..._groups.map((g) {
            final isMine = g.author.id == AuthService().currentUser?.id;
            return _StoryCard(
              label: isMine ? 'Tu historia' : g.author.displayName,
              imageUrl: g.author.image,
              name: g.author.displayName,
              hasGradient: !isMine,
              onTap: () => _openGroup(g, 0),
            );
          }),
        ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
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
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _kStoryWidth,
          height: _kStoryHeight,
          child: hasGradient
              ? Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_kStoryRadius + 1),
                    gradient: KairoColors.logoGradient,
                  ),
                  child: _StoryCardBody(
                    label: label,
                    isAdd: isAdd,
                    imageUrl: imageUrl,
                    name: name,
                  ),
                )
              : _StoryCardBody(
                  label: label,
                  isAdd: isAdd,
                  imageUrl: imageUrl,
                  name: name,
                ),
        ),
      ),
    );
  }
}

class _StoryCardBody extends StatelessWidget {
  const _StoryCardBody({
    required this.label,
    required this.isAdd,
    this.imageUrl,
    this.name,
  });

  final String label;
  final bool isAdd;
  final String? imageUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kStoryRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isAdd)
            Container(
              color: KairoColors.darkCard,
              child: const Center(
                child: Icon(Icons.add, color: KairoColors.primary500, size: 22),
              ),
            )
          else if (imageUrl != null)
            CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          else
            Container(
              color: KairoColors.darkHover,
              alignment: Alignment.center,
              child: Text(
                (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 5),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600, height: 1.1),
                ),
              ),
            ),
          ),
          if (isAdd)
            Positioned(
              right: 4,
              bottom: 22,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: KairoColors.primary500,
                  shape: BoxShape.circle,
                  border: Border.all(color: KairoColors.darkCard, width: 1.5),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}
