import 'package:video_player/video_player.dart';

/// Garantiza que solo un video del feed reproduzca a la vez.
/// El foco lo obtiene el video con mayor visibilidad (≥ 50 %).
class FeedPlaybackFocusManager {
  FeedPlaybackFocusManager._();
  static final FeedPlaybackFocusManager instance = FeedPlaybackFocusManager._();

  static const double minVisibleFraction = 0.5;

  final Set<VideoPlayerController> _registered = {};
  final Map<VideoPlayerController, double> _visibilityByController = {};
  VideoPlayerController? _focused;
  VideoPlayerController? _heldFocus;

  void register(VideoPlayerController controller) {
    _registered.add(controller);
    _visibilityByController[controller] = 0;
  }

  void unregister(VideoPlayerController controller) {
    _registered.remove(controller);
    _visibilityByController.remove(controller);
    if (_focused == controller) _focused = null;
    if (_heldFocus == controller) _heldFocus = null;
    _reconcileFocus();
  }

  /// Pantalla completa: este controlador mantiene el foco exclusivo y sigue sonando.
  void holdFocus(VideoPlayerController controller) {
    _heldFocus = controller;
    _focused = controller;
    _pauseAllExcept(controller);
    if (controller.value.isInitialized && !controller.value.isPlaying) {
      controller.play();
    }
  }

  void releaseHold(VideoPlayerController controller) {
    if (_heldFocus != controller) return;
    _heldFocus = null;
    _reconcileFocus();
  }

  bool isFocused(VideoPlayerController controller) => _focused == controller;

  bool isHeld(VideoPlayerController controller) => _heldFocus == controller;

  bool get hasHeldFocus => _heldFocus != null;

  /// Actualiza la fracción visible y recalcula qué video puede reproducir.
  void updateVisibility(VideoPlayerController controller, double fraction) {
    if (!_registered.contains(controller)) return;
    _visibilityByController[controller] = fraction.clamp(0.0, 1.0);
    if (_heldFocus != null) return;
    _reconcileFocus();
  }

  void pauseAll() {
    // No cortar un video abierto a pantalla completa.
    if (_heldFocus != null) {
      _pauseAllExcept(_heldFocus);
      return;
    }
    _focused = null;
    for (final c in _registered) {
      _visibilityByController[c] = 0;
      if (c.value.isInitialized && c.value.isPlaying) {
        c.pause();
      }
    }
  }

  void _reconcileFocus() {
    if (_heldFocus != null) {
      _focused = _heldFocus;
      _pauseAllExcept(_heldFocus);
      return;
    }

    VideoPlayerController? candidate;
    var bestFraction = 0.0;

    for (final controller in _registered) {
      final fraction = _visibilityByController[controller] ?? 0;
      if (fraction >= minVisibleFraction && fraction > bestFraction) {
        bestFraction = fraction;
        candidate = controller;
      }
    }

    _focused = candidate;
    _pauseAllExcept(candidate);
  }

  void _pauseAllExcept(VideoPlayerController? keep) {
    for (final controller in _registered) {
      if (controller == keep) continue;
      if (controller.value.isInitialized && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }
}
