import 'dart:typed_data';

import '../../../core/constants/chat_limits.dart';
import '../../../core/moderation/kairo_content_policy.dart';

/// Group-specific limits. Content rules come from [KairoContentPolicy].
class GroupContentPolicy {
  static void validateDescription(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.length > ChatLimits.maxGroupDescriptionLength) {
      throw GroupDescriptionException();
    }
    KairoContentPolicy.assertText(text);
  }

  static void validateImage({required Uint8List bytes, required String mimeType}) {
    if (bytes.length > ChatLimits.maxGroupImageBytes) {
      throw GroupImageException(
        'La imagen no puede superar ${ChatLimits.maxGroupImageBytes ~/ (1024 * 1024)} MB.',
      );
    }
    KairoContentPolicy.assertMedia(bytes: bytes, mimeType: mimeType);
  }
}

class GroupDescriptionException implements Exception {
  @override
  String toString() =>
      'La descripción no puede tener más de ${ChatLimits.maxGroupDescriptionLength} caracteres.';
}

class GroupBlockedContentException implements Exception {
  @override
  String toString() => KairoContentPolicy.userMessage;
}

class GroupImageException implements Exception {
  GroupImageException(this.message);
  final String message;
  @override
  String toString() => message;
}
