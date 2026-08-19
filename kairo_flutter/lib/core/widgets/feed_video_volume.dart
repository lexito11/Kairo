import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Volumen global del feed: un solo toggle silencia/reactiva todos los videos activos.
class FeedVideoVolume extends ChangeNotifier {
  FeedVideoVolume._();
  static final FeedVideoVolume instance = FeedVideoVolume._();

  bool _muted = false;
  final Set<VideoPlayerController> _controllers = {};

  bool get isMuted => _muted;
  double get volume => _muted ? 0.0 : 1.0;

  void register(VideoPlayerController controller) {
    _controllers.add(controller);
    applyVolume(controller);
  }

  void unregister(VideoPlayerController controller) {
    _controllers.remove(controller);
  }

  void applyVolume(VideoPlayerController controller) {
    if (controller.value.isInitialized) {
      controller.setVolume(volume);
    }
  }

  void toggle() {
    _muted = !_muted;
    for (final c in _controllers) {
      applyVolume(c);
    }
    notifyListeners();
  }

  /// Pausa todos los videos del feed (p. ej. al cambiar de sección).
  void pauseAll() {
    for (final c in _controllers) {
      if (c.value.isInitialized && c.value.isPlaying) {
        c.pause();
      }
    }
  }
}
