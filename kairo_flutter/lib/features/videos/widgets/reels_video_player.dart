import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/feed_playback_focus_manager.dart';

/// Reproductor vertical estilo Reels: tap pausa/reanuda, bocina solo al pausar,
/// barra de progreso inferior para adelantar/atrasar.
class ReelsVideoPlayer extends StatefulWidget {
  const ReelsVideoPlayer({
    super.key,
    required this.url,
    required this.active,
    required this.height,
  });

  final String url;
  final bool active;
  final double height;

  @override
  State<ReelsVideoPlayer> createState() => _ReelsVideoPlayerState();
}

class _ReelsVideoPlayerState extends State<ReelsVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;
  bool _userPaused = false;
  bool _muted = false;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _registerPlayback();
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      _controller.setVolume(1);
      setState(() => _initialized = true);
      if (widget.active) _controller.play();
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  void _registerPlayback() {
    if (_registered) return;
    FeedPlaybackFocusManager.instance.register(_controller);
    _registered = true;
  }

  void _unregisterPlayback() {
    if (!_registered) return;
    FeedPlaybackFocusManager.instance.unregister(_controller);
    _registered = false;
  }

  @override
  void didUpdateWidget(covariant ReelsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized || !_controller.value.isInitialized) return;

    if (widget.active != oldWidget.active) {
      if (widget.active && !_userPaused) {
        _controller.play();
      } else if (!widget.active) {
        _controller.pause();
      }
    }
  }

  void _togglePlayPause() {
    if (!_initialized || !_controller.value.isInitialized) return;
    setState(() {
      _userPaused = !_userPaused;
      if (_userPaused) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    if (!_initialized || !_controller.value.isInitialized) return;
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    if (_initialized && _controller.value.isInitialized && _controller.value.isPlaying) {
      _controller.pause();
    }
    _unregisterPlayback();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.videocam_off, color: KairoColors.darkTextSecondary),
        ),
      );
    }

    if (!_initialized) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const Center(
          child: CircularProgressIndicator(color: KairoColors.primary500),
        ),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayPause,
            ),
          ),
          if (_userPaused) ...[
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 52),
                ),
              ),
            ),
            Positioned(
              top: topInset + 10,
              right: 10,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 5,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: KairoColors.primary500,
                  bufferedColor: Color(0x66238BDF),
                  backgroundColor: Color(0x332384C7),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
