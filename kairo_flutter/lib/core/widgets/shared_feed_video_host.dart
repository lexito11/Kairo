import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/kairo_layout.dart';
import 'feed_playback_focus_manager.dart';

/// Un único [VideoPlayer] por controlador: vive en la tarjeta del Feed y se
/// reparenta al overlay raíz en pantalla completa, sin dispose ni reload.
class SharedFeedVideoHost extends StatefulWidget {
  const SharedFeedVideoHost({
    super.key,
    required this.controller,
    required this.fullscreen,
    this.placeholder,
  });

  final VideoPlayerController controller;
  final bool fullscreen;
  final Widget? placeholder;

  @override
  State<SharedFeedVideoHost> createState() => _SharedFeedVideoHostState();
}

class _SharedFeedVideoHostState extends State<SharedFeedVideoHost> {
  final GlobalKey _playerKey = GlobalKey();
  final GlobalKey<OverlayState> _localOverlayKey = GlobalKey<OverlayState>();
  OverlayEntry? _entry;
  bool _onRoot = false;
  bool _scheduledSync = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    FeedPlaybackFocusManager.instance.addListener(_onFocusChanged);
    _entry = OverlayEntry(builder: _buildEntry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _localOverlayKey.currentState?.insert(_entry!);
    });
  }

  @override
  void didUpdateWidget(covariant SharedFeedVideoHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
    if (oldWidget.fullscreen != widget.fullscreen) {
      _scheduleSyncParent();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    FeedPlaybackFocusManager.instance.removeListener(_onFocusChanged);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _onTick() {
    _entry?.markNeedsBuild();
  }

  void _onFocusChanged() {
    _entry?.markNeedsBuild();
  }

  void _scheduleSyncParent() {
    if (_scheduledSync) return;
    _scheduledSync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledSync = false;
      if (!mounted) return;
      _syncParent();
    });
  }

  void _syncParent() {
    final entry = _entry;
    if (entry == null || !entry.mounted) {
      if (entry != null && widget.fullscreen && !_onRoot) {
        Overlay.of(context, rootOverlay: true).insert(entry);
        _onRoot = true;
        entry.markNeedsBuild();
      }
      return;
    }

    if (widget.fullscreen && !_onRoot) {
      entry.remove();
      Overlay.of(context, rootOverlay: true).insert(entry);
      _onRoot = true;
      entry.markNeedsBuild();
    } else if (!widget.fullscreen && _onRoot) {
      entry.remove();
      _onRoot = false;
      final local = _localOverlayKey.currentState;
      if (local != null) {
        local.insert(entry);
      }
      entry.markNeedsBuild();
    }
  }

  Widget _player() {
    final c = widget.controller;
    if (!c.value.isInitialized) {
      return widget.placeholder ?? const ColoredBox(color: Color(0xFF000000));
    }
    final size = c.value.size;
    return FittedBox(
      fit: widget.fullscreen ? BoxFit.contain : BoxFit.cover,
      alignment: widget.fullscreen ? Alignment.center : Alignment.topCenter,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(c, key: _playerKey),
      ),
    );
  }

  Widget _buildEntry(BuildContext context) {
    final held = FeedPlaybackFocusManager.instance.heldController;
    final hideForOtherFullscreen = widget.fullscreen &&
        held != null &&
        held != widget.controller;

    if (hideForOtherFullscreen) {
      return const IgnorePointer(child: SizedBox.shrink());
    }

    final painted = ColoredBox(
      color: widget.fullscreen ? Colors.transparent : const Color(0xFF000000),
      child: SizedBox.expand(child: _player()),
    );

    if (!widget.fullscreen) {
      return ClipRect(child: painted);
    }

    return IgnorePointer(
      child: SizedBox.expand(child: painted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: KairoLayout.feedImageAspectRatio,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            Overlay(
              key: _localOverlayKey,
              clipBehavior: Clip.hardEdge,
            ),
          ],
        ),
      ),
    );
  }
}
