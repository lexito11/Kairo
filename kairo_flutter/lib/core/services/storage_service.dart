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

    final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final basePath = subfolder.isEmpty ? userId : '$subfolder/$userId';
    final path = '$basePath/${const Uuid().v4()}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
