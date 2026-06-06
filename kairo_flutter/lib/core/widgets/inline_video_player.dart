import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/kairo_colors.dart';

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({super.key, required this.url, this.height = 280, this.autoPlay = false});

  final String url;
  final double height;
  final bool autoPlay;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        if (widget.autoPlay) _controller.play();
        _controller.setLooping(true);
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Icon(Icons.videocam_off, color: KairoColors.darkTextSecondary)),
      );
    }
    if (!_initialized) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          if (!_controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
        ],
      ),
    );
  }
}
