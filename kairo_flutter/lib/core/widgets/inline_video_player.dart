import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/kairo_colors.dart';

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    super.key,
    required this.url,
    this.controller,
    this.height = 280,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
    this.muted = false,
    this.tapToTogglePlay = true,
    this.onTap,
    this.onControllerReady,
    this.autoDispose = true,
    this.showPlayOverlay = true,
    this.onAspectRatioKnown,
  });

  final String url;
  final VideoPlayerController? controller;
  final double height;
  final double? aspectRatio;
  final BoxFit fit;
  final bool autoPlay;
  final bool muted;
  final bool tapToTogglePlay;
  final VoidCallback? onTap;
  final ValueChanged<VideoPlayerController>? onControllerReady;
  final bool autoDispose;
  final bool showPlayOverlay;
  final ValueChanged<double>? onAspectRatioKnown;

  @override
  State<InlineVideoPlayer> createState() => InlineVideoPlayerState();
}

class InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late VideoPlayerController _controller;
  late bool _ownsController;
  bool _initialized = false;
  bool _error = false;

  VideoPlayerController get controller => _controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
      if (_controller.value.isInitialized) {
        _onInitialized();
      } else {
        _controller.initialize().then((_) {
          if (!mounted) return;
          _onInitialized();
        }).catchError((_) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _error = true);
          });
        });
      }
      _notifyControllerReady();
      return;
    }
    _ownsController = widget.autoDispose;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _bindController();
  }

  void _bindController() {
    _notifyControllerReady();
    _controller.initialize().then((_) {
      if (!mounted) return;
      _onInitialized();
    }).catchError((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = true);
      });
    });
  }

  void _notifyControllerReady() {
    final callback = widget.onControllerReady;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(_controller);
    });
  }

  void _onInitialized() {
    if (!mounted || !_controller.value.isInitialized) return;

    final size = _controller.value.size;
    if (size.width > 0 && size.height > 0) {
      widget.onAspectRatioKnown?.call(size.width / size.height);
    }

    _controller.setVolume(widget.muted ? 0.0 : 1.0);
    _controller.setLooping(true);
    setState(() => _initialized = true);

    if (widget.autoPlay) {
      _controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant InlineVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.muted != oldWidget.muted && _initialized && _controller.value.isInitialized) {
      _controller.setVolume(widget.muted ? 0.0 : 1.0);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void play() {
    if (mounted && _initialized && _controller.value.isInitialized) {
      _controller.play();
    }
  }

  void pause() {
    if (mounted && _initialized && _controller.value.isInitialized) {
      _controller.pause();
    }
  }

  Widget _wrapSized(Widget child) {
    if (widget.aspectRatio != null) {
      return AspectRatio(aspectRatio: widget.aspectRatio!, child: child);
    }
    return SizedBox(height: widget.height, width: double.infinity, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return _wrapSized(
        const Center(child: Icon(Icons.videocam_off, color: KairoColors.darkTextSecondary)),
      );
    }
    if (!_initialized) {
      return _wrapSized(
        const Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
      );
    }

    final player = _wrapSized(
      Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          if (widget.showPlayOverlay && !_controller.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: IgnorePointer(child: player),
      );
    }

    if (!widget.tapToTogglePlay) return player;

    return GestureDetector(
      onTap: () {
        if (!mounted || !_controller.value.isInitialized) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.value.isInitialized) return;
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        });
      },
      child: player,
    );
  }
}
