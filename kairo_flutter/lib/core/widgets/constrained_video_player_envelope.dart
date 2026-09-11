import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/kairo_layout.dart';

/// Envolvente del reproductor en la TARJETA del Feed (no la pantalla completa).
///
/// Marco fijo 4:5 con [BoxFit.cover] y [ClipRect], estilo Instagram.
class ConstrainedVideoPlayerEnvelope extends StatefulWidget {
  const ConstrainedVideoPlayerEnvelope({
    super.key,
    this.controller,
    this.videoAspectRatio,
    this.child,
    this.placeholder,
    this.expand = false,
    this.enableOrientationFullscreen = true,
    this.onEnterLandscape,
    this.onExitLandscape,
  });

  static const feedCardAspect = KairoLayout.feedImageAspectRatio;

  final VideoPlayerController? controller;
  final double? videoAspectRatio;
  final Widget? child;
  final Widget? placeholder;
  final bool expand;
  final bool enableOrientationFullscreen;
  final VoidCallback? onEnterLandscape;
  final VoidCallback? onExitLandscape;

  @override
  State<ConstrainedVideoPlayerEnvelope> createState() =>
      _ConstrainedVideoPlayerEnvelopeState();
}

class _ConstrainedVideoPlayerEnvelopeState
    extends State<ConstrainedVideoPlayerEnvelope>
    with WidgetsBindingObserver {
  Orientation? _lastOrientation;
  bool _openedByOrientation = false;
  bool _wasReady = false;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncReadySnapshot(widget.controller);
    widget.controller?.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant ConstrainedVideoPlayerEnvelope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerTick);
      _syncReadySnapshot(widget.controller);
      widget.controller?.addListener(_onControllerTick);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_onControllerTick);
    super.dispose();
  }

  void _syncReadySnapshot(VideoPlayerController? controller) {
    final ready = controller != null && controller.value.isInitialized;
    _wasReady = ready;
    _lastSize = ready ? controller.value.size : Size.zero;
  }

  void _onControllerTick() {
    final controller = widget.controller;
    if (controller == null) return;
    final ready = controller.value.isInitialized;
    final size = ready ? controller.value.size : Size.zero;
    if (ready == _wasReady && size == _lastSize) return;
    _wasReady = ready;
    _lastSize = size;
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    _syncOrientation();
  }

  bool get _isHandheld {
    final data = MediaQuery.maybeOf(context);
    if (data == null) return false;
    if (data.size.shortestSide >= 600) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Orientation _currentOrientation() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      final size = views.first.physicalSize;
      if (size.width > 0 && size.height > 0) {
        return size.width > size.height ? Orientation.landscape : Orientation.portrait;
      }
    }
    return MediaQuery.maybeOf(context)?.orientation ?? Orientation.portrait;
  }

  void _syncOrientation() {
    if (!widget.enableOrientationFullscreen || !mounted || !_isHandheld) return;
    final next = _currentOrientation();
    final prev = _lastOrientation ?? next;
    _lastOrientation = next;
    if (next == prev) return;

    if (next == Orientation.landscape && prev == Orientation.portrait) {
      _openedByOrientation = true;
      widget.onEnterLandscape?.call();
    } else if (next == Orientation.portrait &&
        prev == Orientation.landscape &&
        _openedByOrientation) {
      _openedByOrientation = false;
      widget.onExitLandscape?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lastOrientation == null) {
        _lastOrientation = _currentOrientation();
      }
    });

    final controller = widget.controller;
    final ready = controller != null && controller.value.isInitialized;
    final size = ready ? controller.value.size : Size.zero;

    Widget content;
    if (!ready) {
      content = widget.placeholder ??
          widget.child ??
          const ColoredBox(color: Color(0xFF000000));
    } else {
      content = FittedBox(
        fit: widget.expand ? BoxFit.contain : BoxFit.cover,
        alignment: widget.expand ? Alignment.center : Alignment.topCenter,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: RepaintBoundary(
            child: widget.child ?? VideoPlayer(controller),
          ),
        ),
      );
    }

    final painted = ClipRect(
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: SizedBox.expand(child: content),
      ),
    );

    if (widget.expand) return painted;
    return AspectRatio(
      aspectRatio: ConstrainedVideoPlayerEnvelope.feedCardAspect,
      child: painted,
    );
  }
}
