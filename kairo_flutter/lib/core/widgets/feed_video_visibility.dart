import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Pausa/reproduce un video según si está completamente visible en el viewport.
class FeedVideoVisibility extends StatefulWidget {
  const FeedVideoVisibility({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.bottomInset = 80,
  });

  final VideoPlayerController controller;
  final Widget child;
  final bool enabled;
  final double bottomInset;

  @override
  State<FeedVideoVisibility> createState() => FeedVideoVisibilityState();
}

class FeedVideoVisibilityState extends State<FeedVideoVisibility> {
  final _key = GlobalKey();
  ScrollPosition? _scrollPosition;
  bool _fullyVisible = false;
  bool _enabled = true;
  bool _evaluateScheduled = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _scheduleEvaluate();
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
      _scheduleApplyPlayback();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleEvaluate);
    super.dispose();
  }

  void setVisibilityTrackingEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    _scheduleApplyPlayback();
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

  void _scheduleApplyPlayback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPlayback();
    });
  }

  bool _checkFullyVisible() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;

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
    if (intersection.isEmpty) return false;

    // Al menos ~40 % del área del video visible para considerar autoplay activo.
    final visibleFraction = (intersection.width * intersection.height) / (rect.width * rect.height);
    return visibleFraction >= 0.4;
  }

  void _evaluate() {
    if (!mounted) return;
    final visible = _checkFullyVisible();
    if (visible != _fullyVisible) {
      _fullyVisible = visible;
      _applyPlayback();
    }
  }

  void _applyPlayback() {
    if (!mounted) return;
    final controller = widget.controller;
    if (!controller.value.isInitialized) return;

    if (_enabled && _fullyVisible) {
      controller.setVolume(1.0);
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
