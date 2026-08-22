import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/story.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../features/auth/services/auth_service.dart';
import '../services/stories_repository.dart';
import 'story_viewer.dart';

/// Tarjetas verticales compactas estilo Facebook Stories.
final _kStoryWidth = ResponsiveBreakpoints.feedStoryCardWidth;
final _kStoryHeight = ResponsiveBreakpoints.feedStoryCardHeight;
const _kStoryRadius = 10.0;
final _kStripHeight = ResponsiveBreakpoints.feedStoriesHeight;

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

  String? get _myProfileImage {
    final uid = AuthService().currentUser?.id;
    if (uid == null) return null;
    for (final g in _groups) {
      if (g.author.id == uid) return g.author.image;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: _kStripHeight,
        child: const Center(child: CircularProgressIndicator(color: KairoColors.primary500, strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: _kStripHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (AuthService().isSignedIn)
            _StoryCard(
              label: 'Tu historia',
              isAdd: true,
              profileImageUrl: _myProfileImage,
              onTap: _addStory,
            ),
          ..._groups.map((g) {
            final isMine = g.author.id == AuthService().currentUser?.id;
            final previewStory = g.stories.isNotEmpty ? g.stories.last : null;
            return _StoryCard(
              label: isMine ? 'Tu historia' : g.author.displayName,
              profileImageUrl: g.author.image,
              previewStory: previewStory,
              hasGradient: !isMine,
              onTap: () => _openGroup(g, 0),
            );
          }),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.label,
    this.isAdd = false,
    this.hasGradient = false,
    this.profileImageUrl,
    this.previewStory,
    this.onTap,
  });

  final String label;
  final bool isAdd;
  final bool hasGradient;
  final String? profileImageUrl;
  final Story? previewStory;
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
                    profileImageUrl: profileImageUrl,
                    previewStory: previewStory,
                  ),
                )
              : _StoryCardBody(
                  label: label,
                  isAdd: isAdd,
                  profileImageUrl: profileImageUrl,
                  previewStory: previewStory,
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
    this.profileImageUrl,
    this.previewStory,
  });

  final String label;
  final bool isAdd;
  final String? profileImageUrl;
  final Story? previewStory;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kStoryRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _StoryCardMedia(
            isAdd: isAdd,
            profileImageUrl: profileImageUrl,
            previewStory: previewStory,
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

class _StoryCardMedia extends StatelessWidget {
  const _StoryCardMedia({
    required this.isAdd,
    this.profileImageUrl,
    this.previewStory,
  });

  final bool isAdd;
  final String? profileImageUrl;
  final Story? previewStory;

  @override
  Widget build(BuildContext context) {
    if (isAdd) {
      if (profileImageUrl != null) {
        return CachedNetworkImage(imageUrl: profileImageUrl!, fit: BoxFit.cover);
      }
      return ColoredBox(
        color: KairoColors.darkCard,
        child: Center(child: Icon(Icons.add, color: KairoColors.primary500.withValues(alpha: 0.9), size: 22)),
      );
    }

    final story = previewStory;
    if (story != null && story.isVideo) {
      return _StoryCardVideo(url: story.mediaUrl);
    }
    if (story != null && !story.isVideo) {
      return CachedNetworkImage(imageUrl: story.mediaUrl, fit: BoxFit.cover);
    }
    if (profileImageUrl != null) {
      return CachedNetworkImage(imageUrl: profileImageUrl!, fit: BoxFit.cover);
    }

    return const ColoredBox(color: KairoColors.darkHover);
  }
}

/// Reproductor aislado para la vista previa de historias (no usa la lógica del feed).
class _StoryCardVideo extends StatefulWidget {
  const _StoryCardVideo({required this.url});

  final String url;

  @override
  State<_StoryCardVideo> createState() => _StoryCardVideoState();
}

class _StoryCardVideoState extends State<_StoryCardVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setVolume(0)
          ..setLooping(true)
          ..play();
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return profileFallback();
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget profileFallback() {
    return const ColoredBox(
      color: KairoColors.darkHover,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary500),
        ),
      ),
    );
  }
}
