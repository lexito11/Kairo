import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'media';

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String subfolder = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Debes iniciar sesión para subir archivos');

    var ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (ext.isEmpty || ext.length > 4 || ext == 'bin' || ext == 'blob') {
      if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        ext = 'jpg';
      } else if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
        ext = 'png';
      } else {
        ext = 'jpg';
      }
    }
    final contentType = mimeType.startsWith('image/')
        ? mimeType
        : (ext == 'png' ? 'image/png' : 'image/jpeg');

    final basePath = subfolder.isEmpty ? userId : '$subfolder/$userId';
    final path = '$basePath/${const Uuid().v4()}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
