import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../moderation/kairo_content_policy.dart';

class StorageService {
  StorageService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'media';
  static const maxUploadBytes = 300 * 1024 * 1024;
  static const tooLargeMessage =
      'El video sigue pesando más de 300 MB después de optimizarlo. Reduce el tamaño e inténtalo de nuevo.';

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String subfolder = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Debes iniciar sesión para subir archivos');
    if (bytes.length > maxUploadBytes) {
      throw Exception(tooLargeMessage);
    }
    final mime = mimeType.toLowerCase().split(';').first.trim();
    if (mime == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf')) {
      KairoContentPolicy.assertText(fileName.replaceAll(RegExp(r'[_\-\.]'), ' '));
    } else {
      KairoContentPolicy.assertMedia(
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
    }

    var ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (ext.isEmpty || ext.length > 4 || ext == 'bin' || ext == 'blob') {
      if (mimeType.startsWith('video/')) {
        ext = mimeType.contains('webm') ? 'webm' : 'mp4';
      } else if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        ext = 'jpg';
      } else if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
        ext = 'png';
      } else {
        ext = 'jpg';
      }
    }

    final String contentType;
    if (mimeType.startsWith('video/')) {
      contentType = mimeType;
    } else if (mimeType.startsWith('image/')) {
      contentType = mimeType;
    } else {
      contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    }

    final basePath = subfolder.isEmpty ? userId : '$subfolder/$userId';
    final path = '$basePath/${const Uuid().v4()}.$ext';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
    } on StorageException catch (e) {
      final code = e.statusCode?.toString() ?? '';
      if (code == '413' || e.message.toLowerCase().contains('maximum allowed size')) {
        throw Exception(tooLargeMessage);
      }
      throw Exception(e.message);
    }

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
