import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/story.dart';
import '../../../core/utils/format_time_ago.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../messages/services/messages_repository.dart';
import '../services/stories_repository.dart';
import 'story_send_sheet.dart';

class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialStoryIndex = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  static const _imageDuration = Duration(seconds: 5);

  final _storiesRepo = StoriesRepository();
  final _messagesRepo = MessagesRepository();
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  late int _groupIndex;
  late int _storyIndex;
  late final AnimationController _progress;

  final Set<String> _likedIds = {};
  bool _paused = false;
  bool _holding = false;
  bool _sendingReply = false;
  bool _liking = false;
  bool _endedHandled = false;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex;
    _storyIndex = widget.initialStoryIndex;
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goNext();
      });
    _replyFocus.addListener(_onFocusChange);
    _replyController.addListener(_onReplyChanged);
    _loadLikes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProgress());
  }

  @override
  void dispose() {
    _replyFocus.removeListener(_onFocusChange);
    _replyFocus.dispose();
    _replyController.removeListener(_onReplyChanged);
    _replyController.dispose();
    _progress.dispose();
    super.dispose();
  }

  StoryGroup get _group => widget.groups[_groupIndex];
  Story get _story => _group.stories[_storyIndex];
  bool get _isOwn {
    final uid = AuthService().currentUser?.id;
    return uid != null && uid == _group.author.id;
  }

  String? get _soundLabel {
    final named = _story.soundName?.trim();
    if (named != null && named.isNotEmpty) return named;
    if (_story.isVideo) return 'Audio original';
    return null;
  }

  Future<void> _loadLikes() async {
    final ids = widget.groups.expand((g) => g.stories.map((s) => s.id));
    try {
      final liked = await _storiesRepo.likedStoryIds(ids);
      if (mounted) setState(() => _likedIds.addAll(liked));
    } catch (_) {}
  }

  void _onReplyChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChange() {
    if (_replyFocus.hasFocus) {
      _setPaused(true);
    } else if (!_holding) {
      _setPaused(false);
    }
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    setState(() => _paused = paused);
    if (paused) {
      _progress.stop();
    } else if (_progress.duration != null && _progress.value < 1) {
      _progress.forward();
    }
  }

  void _startProgress({Duration? videoDuration}) {
    if (!mounted) return;
    _endedHandled = false;
    _progress.stop();
    _progress.value = 0;
    final duration = videoDuration ?? (_story.isVideo ? null : _imageDuration);
    if (duration == null) return;
    _progress.duration = duration;
    if (_paused) return;
    _progress.forward();
  }

  void _goNext() {
    if (!mounted || _endedHandled) return;
    _endedHandled = true;
    _replyFocus.unfocus();
    final group = _group;
    if (_storyIndex < group.stories.length - 1) {
      setState(() => _storyIndex++);
      _startProgress();
    } else if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex++;
        _storyIndex = 0;
      });
      _startProgress();
    } else {
      Navigator.pop(context);
    }
  }

  void _goPrev() {
    _replyFocus.unfocus();
    _endedHandled = false;
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _startProgress();
    } else if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _storyIndex = widget.groups[_groupIndex].stories.length - 1;
      });
      _startProgress();
    } else {
      _progress.forward(from: 0);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_holding || _replyFocus.hasFocus) return;
    final dx = details.localPosition.dx;
    final width = MediaQuery.sizeOf(context).width;
    if (dx > width * 0.35) {
      _goNext();
    } else {
      _goPrev();
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sendingReply || _isOwn) return;
    setState(() => _sendingReply = true);
    try {
      await _messagesRepo.sendMessage(
        _group.author.id,
        text,
        mediaUrl: _story.mediaUrl,
        mediaType: _story.mediaType,
      );
      _replyController.clear();
      _replyFocus.unfocus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensaje enviado')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje')),
      );
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_liking || _isOwn) return;
    final id = _story.id;
    final wasLiked = _likedIds.contains(id);
    setState(() {
      _liking = true;
      if (wasLiked) {
        _likedIds.remove(id);
      } else {
        _likedIds.add(id);
      }
    });
    try {
      final liked = await _storiesRepo.toggleLike(id);
      if (!mounted) return;
      setState(() {
        if (liked) {
          _likedIds.add(id);
        } else {
          _likedIds.remove(id);
        }
      });
      if (liked && !wasLiked) {
        try {
          await _messagesRepo.sendMessage(
            _group.author.id,
            '❤️',
            mediaUrl: _story.mediaUrl,
            mediaType: _story.mediaType,
          );
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedIds.add(id);
        } else {
          _likedIds.remove(id);
        }
      });
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _openSendSheet() async {
    _setPaused(true);
    await showStorySendSheet(context, story: _story);
    if (mounted && !_replyFocus.hasFocus && !_holding) _setPaused(false);
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final group = _group;
    final liked = _likedIds.contains(story.id);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sound = _soundLabel;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onLongPressStart: (_) {
                _holding = true;
                _setPaused(true);
              },
              onLongPressEnd: (_) {
                _holding = false;
                if (!_replyFocus.hasFocus) _setPaused(false);
              },
              child: story.isVideo
                  ? _StoryVideo(
                      key: ValueKey(story.id),
                      url: story.mediaUrl,
                      paused: _paused,
                      onDuration: (duration) {
                        if (_story.id == story.id) {
                          _startProgress(videoDuration: duration);
                        }
                      },
                      onEnded: () {
                        if (_story.id == story.id) _goNext();
                      },
                    )
                  : CachedNetworkImage(
                      imageUrl: story.mediaUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Colors.black),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 48),
                      ),
                    ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => _ProgressBars(
                        count: group.stories.length,
                        currentIndex: _storyIndex,
                        progress: _progress.value,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
                    child: Row(
                      children: [
                        KairoAvatar(
                          imageUrl: group.author.image,
                          name: group.author.displayName,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: group.author.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '  · ${formatTimeAgo(story.createdAt)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sound != null) ...[
                          const SizedBox(width: 8),
                          _MusicChip(label: sound),
                        ],
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                      child: IgnorePointer(child: SizedBox.expand())),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        12, 0, 8, 10 + (bottomInset > 0 ? 0 : 4)),
                    child: Row(
                      children: [
                        if (!_isOwn)
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              focusNode: _replyFocus,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendReply(),
                              decoration: InputDecoration(
                                hintText: 'Mensaje...',
                                hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.18),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.55)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                                suffixIcon: _replyController.text.trim().isEmpty
                                    ? null
                                    : (_sendingReply
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white),
                                            ),
                                          )
                                        : IconButton(
                                            onPressed: _sendReply,
                                            icon: const Icon(Icons.arrow_upward,
                                                color: Colors.white, size: 20),
                                          )),
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (!_isOwn) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: _toggleLike,
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                        IconButton(
                          onPressed: _openSendSheet,
                          icon: const Icon(Icons.send,
                              color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({
    required this.count,
    required this.currentIndex,
    required this.progress,
  });

  final int count;
  final int currentIndex;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final n = count < 1 ? 1 : count;
    return Row(
      children: List.generate(n, (i) {
        final value = i < currentIndex
            ? 1.0
            : i > currentIndex
                ? 0.0
                : progress.clamp(0.0, 1.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.35),
                color: Colors.white,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MusicChip extends StatelessWidget {
  const _MusicChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryVideo extends StatefulWidget {
  const _StoryVideo({
    super.key,
    required this.url,
    required this.paused,
    required this.onDuration,
    required this.onEnded,
  });

  final String url;
  final bool paused;
  final ValueChanged<Duration> onDuration;
  final VoidCallback onEnded;

  @override
  State<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<_StoryVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _notifiedDuration = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(false)
          ..setVolume(1);
        if (!widget.paused) _controller.play();
        setState(() => _ready = true);
        _notifyDuration();
      });
    _controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _StoryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (widget.paused) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _notifyDuration() {
    if (_notifiedDuration) return;
    final duration = _controller.value.duration;
    if (duration == Duration.zero) return;
    _notifiedDuration = true;
    widget.onDuration(duration);
  }

  void _onTick() {
    if (!_ready || _ended) return;
    final value = _controller.value;
    if (value.duration == Duration.zero) return;
    if (value.position >= value.duration - const Duration(milliseconds: 80)) {
      _ended = true;
      widget.onEnded();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
