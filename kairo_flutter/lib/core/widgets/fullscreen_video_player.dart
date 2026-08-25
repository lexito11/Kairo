import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/kairo_colors.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  const FullscreenVideoPlayer({
    super.key,
    required this.controller,
    this.onClose,
    this.showVideoLayer = true,
  });

  final VideoPlayerController controller;
  final VoidCallback? onClose;
  /// Si es false, solo muestra controles (el video vive en un Hero externo).
  final bool showVideoLayer;

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _showCenterIcon = false;
  Timer? _hideIconTimer;

  VideoPlayerController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onVideoUpdate);
    // Al abrir detalle, el video debe seguir reproduciéndose.
    if (_c.value.isInitialized && !_c.value.isPlaying) {
      _c.play();
    }
  }

  @override
  void dispose() {
    _hideIconTimer?.cancel();
    _c.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _flashCenterIcon() {
    setState(() => _showCenterIcon = true);
    _hideIconTimer?.cancel();
    _hideIconTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showCenterIcon = false);
    });
  }

  void _togglePlay() {
    if (!mounted || !_c.value.isInitialized) return;
    if (_c.value.isPlaying) {
      _c.pause();
    } else {
      _c.play();
    }
    _flashCenterIcon();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: KairoColors.primary500));
    }

    final size = _c.value.size;
    final isPlaying = _c.value.isPlaying;

    final progressBar = Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                _c,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: KairoColors.primary500,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(_c.value.position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _format(_c.value.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.showVideoLayer) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (_showCenterIcon || !isPlaying)
              IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            progressBar,
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_c),
                  ),
                ),
              ),
            ),
          ),
          if (_showCenterIcon || !isPlaying)
            IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          progressBar,
        ],
      ),
    );
  }
}
