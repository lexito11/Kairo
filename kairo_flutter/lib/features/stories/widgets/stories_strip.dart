import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/story.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../users/services/users_repository.dart';
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

class _StoriesStripState extends State<StoriesStrip> with RouteAware {
  final _repo = StoriesRepository();
  final _users = UsersRepository();
  List<StoryGroup> _groups = [];
  String? _profileImage;
  String? _profileName;
  bool _loading = true;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void didPopNext() {
    _load();
  }

  @override
  void dispose() {
    if (_subscribed) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (!AuthService().isSignedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final groups = await _repo.fetchStoryGroups();
      final me = await _users.getCurrentUser();
      if (!mounted) return;
      String? profileImage = me?.image;
      final uid = AuthService().currentUser?.id;
      if ((profileImage == null || profileImage.isEmpty) && uid != null) {
        for (final g in groups) {
          if (g.author.id == uid && g.author.image != null) {
            profileImage = g.author.image;
            break;
          }
        }
      }
      setState(() {
        _groups = groups;
        _profileImage = profileImage;
        _profileName = me?.displayName;
        _loading = false;
      });
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
        builder: (_) => StoryViewer(
          groups: _groups,
          initialGroupIndex: _groups.indexOf(group),
          initialStoryIndex: initialIndex,
        ),
      ),
    );
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
              profileImageUrl: _profileImage,
              profileName: _profileName,
              onTap: _addStory,
            ),
          ..._groups.map((g) {
            final isMine = g.author.id == AuthService().currentUser?.id;
            return _StoryCard(
              label: isMine ? 'Tu historia' : g.author.displayName,
              profileImageUrl: g.author.image,
              stories: g.stories,
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
    this.profileImageUrl,
    this.profileName,
    this.stories = const [],
    this.onTap,
  });

  final String label;
  final bool isAdd;
  final String? profileImageUrl;
  final String? profileName;
  final List<Story> stories;
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kStoryRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isAdd)
                  _AddStoryBackground(
                    profileImageUrl: profileImageUrl,
                    profileName: profileName ?? label,
                  )
                else
                  _StoryCollage(stories: stories, fallbackImageUrl: profileImageUrl),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xCC000000)],
                      ),
                    ),
                    child: SizedBox(height: 36),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 4,
                  bottom: 5,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)],
                    ),
                  ),
                ),
                if (isAdd)
                  const Center(
                    child: Icon(Icons.add, color: Color(0xFFE0F2FE), size: 40),
                  )
                else
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _RingAvatar(imageUrl: profileImageUrl, name: label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddStoryBackground extends StatelessWidget {
  const _AddStoryBackground({this.profileImageUrl, this.profileName});

  final String? profileImageUrl;
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    final url = profileImageUrl;
    if (url != null && url.isNotEmpty) {
      final photo = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => _ProfileFallback(name: profileName),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb)
            photo
          else
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
              child: Transform.scale(scale: 1.08, child: photo),
            ),
          const ColoredBox(color: Color(0x33000000)),
        ],
      );
    }
    return _ProfileFallback(name: profileName);
  }
}

class _ProfileFallback extends StatelessWidget {
  const _ProfileFallback({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : 'A';
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: KairoColors.logoGradient),
      child: Center(
        child: Opacity(
          opacity: 0.4,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 42,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingAvatar extends StatelessWidget {
  const _RingAvatar({this.imageUrl, this.name});

  final String? imageUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [KairoColors.primary400, Color(0xFF2563EB)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(1.4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: KairoColors.darkBg,
        ),
        child: KairoAvatar(imageUrl: imageUrl, name: name, size: 22),
      ),
    );
  }
}

class _StoryCollage extends StatelessWidget {
  const _StoryCollage({required this.stories, this.fallbackImageUrl});

  final List<Story> stories;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      if (fallbackImageUrl != null) {
        return CachedNetworkImage(imageUrl: fallbackImageUrl!, fit: BoxFit.cover);
      }
      return const ColoredBox(color: KairoColors.darkHover);
    }
    if (stories.length == 1) {
      return _StoryThumb(story: stories.first);
    }
    if (stories.length == 2) {
      return Column(
        children: [
          Expanded(child: _StoryThumb(story: stories[0])),
          const SizedBox(height: 1),
          Expanded(child: _StoryThumb(story: stories[1])),
        ],
      );
    }
    if (stories.length == 3) {
      return Column(
        children: [
          Expanded(flex: 3, child: _StoryThumb(story: stories[0])),
          const SizedBox(height: 1),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(child: _StoryThumb(story: stories[1])),
                const SizedBox(width: 1),
                Expanded(child: _StoryThumb(story: stories[2])),
              ],
            ),
          ),
        ],
      );
    }
    final tiles = stories.take(4).toList();
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _StoryThumb(story: tiles[0])),
              const SizedBox(width: 1),
              Expanded(child: _StoryThumb(story: tiles[1])),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _StoryThumb(story: tiles[2])),
              const SizedBox(width: 1),
              Expanded(child: _StoryThumb(story: tiles[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoryThumb extends StatelessWidget {
  const _StoryThumb({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    if (story.isVideo) {
      return _StoryCardVideo(url: story.mediaUrl);
    }
    return CachedNetworkImage(
      imageUrl: story.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, __, ___) => const ColoredBox(color: KairoColors.darkHover),
    );
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
}
