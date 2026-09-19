import 'package:flutter/foundation.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class VideoIngestException implements Exception {
  VideoIngestException(this.message);
  final String message;

  @override
  String toString() => message;
}

class VideoIngestResult {
  const VideoIngestResult({
    required this.bytes,
    required this.name,
    required this.mime,
    this.path,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
  final String? path;
}

/// Validación de duración/peso y compresión previa a la subida.
/// No altera el Feed ni la reproducción.
class VideoIngestService {
  static const maxPickBytes = 500 * 1024 * 1024;
  static const maxUploadBytes = 300 * 1024 * 1024;
  static const targetCompressedBytesMin = 150 * 1024 * 1024;
  static const maxDuration = Duration(minutes: 3);
  static const _trimEndMs = 180000;
  static const _maxWidth = 1920;
  static const _maxHeight = 1080;
  static const _bitrateKbps = 7000;

  static const tooHeavyPickMessage =
      'El video original no puede superar 500 MB. Elige un archivo más liviano.';
  static const tooLongMessage =
      'El video no puede durar más de 3 minutos. Recórtalo e inténtalo de nuevo.';
  static const tooLargeAfterCompressMessage =
      'El video sigue pesando más de 300 MB después de optimizarlo. Reduce el tamaño e inténtalo de nuevo.';

  bool get _canTrimOnPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _canCompressOnPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<VideoIngestResult> prepare({
    required String name,
    required Uint8List originalBytes,
    String? path,
  }) async {
    if (originalBytes.length > maxPickBytes) {
      throw VideoIngestException(tooHeavyPickMessage);
    }

    final duration = path == null || path.isEmpty ? null : await _readDuration(path);
    final needsTrim = duration != null && duration > maxDuration;
    if (needsTrim && !_canTrimOnPlatform) {
      throw VideoIngestException(tooLongMessage);
    }

    var outBytes = originalBytes;
    var outPath = path;
    var outName = _mp4Name(name);

    if (_canCompressOnPlatform && path != null && path.isNotEmpty) {
      try {
        final compressed = await _compress(
          path: path,
          trimFirstThreeMinutes: needsTrim,
        );
        if (compressed != null && compressed.bytes.isNotEmpty) {
          outBytes = compressed.bytes;
          outPath = compressed.path;
          outName = _mp4Name(name);
        }
      } on VideoIngestException {
        rethrow;
      } catch (_) {
        outBytes = originalBytes;
        outPath = path;
      }
    }

    if (outBytes.length > maxUploadBytes) {
      throw VideoIngestException(tooLargeAfterCompressMessage);
    }

    return VideoIngestResult(
      bytes: outBytes,
      name: outName,
      mime: 'video/mp4',
      path: outPath,
    );
  }

  Future<({Uint8List bytes, String path})?> _compress({
    required String path,
    required bool trimFirstThreeMinutes,
  }) async {
    final result = await FlutterCompress.instance.compress(
      path,
      VideoCompressConfig(
        codec: VideoCodec.h264,
        maxWidth: _maxWidth,
        maxHeight: _maxHeight,
        videoBitrateKbps: _bitrateKbps,
        targetSizeMB: 220,
        keepOriginalIfLarger: true,
        container: VideoContainer.mp4,
        trim: trimFirstThreeMinutes
            ? const TrimRange(startMs: 0, endMs: _trimEndMs)
            : null,
      ),
    );
    final outputPath = result.outputPath;
    if (outputPath.isEmpty) return null;
    final bytes = await XFile(outputPath).readAsBytes();
    return (bytes: bytes, path: outputPath);
  }

  Future<Duration?> _readDuration(String path) async {
    VideoPlayerController? controller;
    try {
      final uri = Uri.tryParse(path);
      final canNetwork = path.startsWith('blob:') ||
          path.startsWith('http') ||
          path.startsWith('data:') ||
          kIsWeb;
      controller = canNetwork && uri != null
          ? VideoPlayerController.networkUrl(uri)
          : VideoPlayerController.networkUrl(Uri.file(path));
      await controller.initialize();
      return controller.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }

  String _mp4Name(String name) {
    final base = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    final clean = base.trim().isEmpty ? 'video' : base.trim();
    return '$clean.mp4';
  }
}
