import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'feed_playback_focus_manager.dart';
import 'feed_video_volume.dart';

/// Reproduce/pausa un video del feed solo si ≥50 % visible en pantalla y la ruta está activa.
class FeedVideoVisibility extends StatefulWidget {
  const FeedVideoVisibility({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.bottomInset = 80,
    this.minVisibleFraction = 0.5,
  });

  final VideoPlayerController controller;
  final Widget child;
  final bool enabled;
  final double bottomInset;
  /// Fracción mínima del área del video que debe verse (0.5 = mitad o más).
  final double minVisibleFraction;

  @override
  State<FeedVideoVisibility> createState() => FeedVideoVisibilityState();
}

class FeedVideoVisibilityState extends State<FeedVideoVisibility> with WidgetsBindingObserver {
  final _key = GlobalKey();
  ScrollPosition? _scrollPosition;
  bool _meetsVisibilityThreshold = false;
  bool _enabled = true;
  bool _appActive = true;
  bool _evaluateScheduled = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    WidgetsBinding.instance.addObserver(this);
    _scheduleEvaluate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _applyPlayback();
    if (active) _scheduleEvaluate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleEvaluate);
      _scrollPosition = position;
      _scrollPosition?.addListener(_scheduleEvaluate);
      _scheduleEvaluate();
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _enabled = widget.enabled;
      if (_enabled) {
        _scheduleEvaluate();
      } else {
        _applyPlayback();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_scheduleEvaluate);
    super.dispose();
  }

  void setVisibilityTrackingEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      _scheduleEvaluate();
    }
  }

  void refreshVisibility() {
    _scheduleEvaluate();
  }

  void _scheduleEvaluate() {
    if (_evaluateScheduled) return;
    _evaluateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateScheduled = false;
      if (!mounted) return;
      _evaluate();
    });
  }

  bool _isRouteCurrent() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  double _visibleFraction() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;

    final offset = box.localToGlobal(Offset.zero);
    final rect = offset & box.size;
    final mediaQuery = MediaQuery.of(context);
    final viewport = Rect.fromLTWH(
      0,
      mediaQuery.padding.top,
      mediaQuery.size.width,
      mediaQuery.size.height - mediaQuery.padding.top - widget.bottomInset,
    );

    final intersection = rect.intersect(viewport);
    if (intersection.isEmpty) return 0;

    return (intersection.width * intersection.height) / (rect.width * rect.height);
  }

  void _evaluate() {
    if (!mounted) return;
    _meetsVisibilityThreshold = _visibleFraction() >= widget.minVisibleFraction;
    _applyPlayback();
  }

  void _applyPlayback() {
    if (!mounted) return;
    final controller = widget.controller;
    if (!controller.value.isInitialized) return;

    // Pantalla completa: no interferir con la reproducción en curso.
    if (!_enabled) return;

    final fraction = _visibleFraction();
    _meetsVisibilityThreshold = fraction >= widget.minVisibleFraction;

    final shouldPlay =
        _appActive && _isRouteCurrent() && _meetsVisibilityThreshold;

    FeedPlaybackFocusManager.instance.updateVisibility(
      controller,
      shouldPlay ? fraction : 0,
    );

    if (shouldPlay && FeedPlaybackFocusManager.instance.isFocused(controller)) {
      FeedVideoVolume.instance.applyVolume(controller);
      if (!controller.value.isPlaying) {
        controller.play();
      }
    } else if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
