import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/event_item.dart';
import '../../../core/moderation/kairo_content_policy.dart';
import '../../../core/services/storage_service.dart';
import '../models/estado_verificacion.dart';
import '../models/event_data.dart';

class EventsRepository {
  EventsRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  final SupabaseClient _client;
  final StorageService _storage;

  static const _select =
      'id, title, location, description, event_date, denomination, category, image_url, church_id, created_by, estado_verificacion, church:churches!church_id(id, name)';

  String? get _userId => _client.auth.currentUser?.id;

  String mapError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('events') && (raw.contains('does not exist') || raw.contains('42p01'))) {
      return 'Falta ejecutar la migración de Eventos en Supabase.';
    }
    if (raw.contains('category') || raw.contains('image_url') || raw.contains('column')) {
      return 'Falta ejecutar la migración 026_events_catalog.sql en Supabase.';
    }
    if (raw.contains('failed to fetch') || raw.contains('socketexception') || raw.contains('network')) {
      return 'No se pudo conectar. Revisa tu internet.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<List<EventItem>> fetchUpcoming({String? denomination}) async {
    final start = DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String();
    List rows;
    try {
      rows = await _client
          .from('events')
          .select(_select)
          .eq('estado_verificacion', EstadoVerificacion.activo)
          .gte('event_date', start)
          .order('event_date', ascending: true)
          .limit(80) as List;
    } catch (_) {
      rows = await _client
          .from('events')
          .select()
          .gte('event_date', start)
          .order('event_date', ascending: true)
          .limit(80) as List;
    }

    var list = rows.map((r) => EventItem.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    if (denomination != null && denomination.isNotEmpty && denomination != 'general') {
      list = list.where((e) {
        final value = (e.denomination ?? '').toLowerCase();
        return value.isEmpty || value == 'general' || value == denomination.toLowerCase();
      }).toList();
    }
    return list;
  }

  Future<EventItem?> fetchById(String id) async {
    final row = await _client.from('events').select(_select).eq('id', id).maybeSingle();
    if (row == null) return null;
    return EventItem.fromJson(row);
  }

  Future<bool> hasPendingEventRequest() async {
    final uid = _userId;
    if (uid == null) return false;

    final rows = await _client
        .from('events')
        .select('id')
        .eq('created_by', uid)
        .eq('estado_verificacion', EstadoVerificacion.pendiente)
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  Future<EventItem> requestEvent({
    required EventRequestFormData form,
    required String? churchId,
    required String? denomination,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');
    KairoContentPolicy.assertText(form.title);
    KairoContentPolicy.assertText(form.description);
    KairoContentPolicy.assertText(form.location);

    final when = form.eventDateTime;
    if (when == null) throw Exception('Fecha u hora no válidas');

    String? imageUrl;
    if (form.hasImage) {
      imageUrl = await _storage.uploadBytes(
        bytes: form.imageBytes!,
        fileName: form.imageName ?? 'event.jpg',
        mimeType: form.imageMime ?? 'image/jpeg',
        subfolder: 'events',
      );
    }

    final payload = <String, dynamic>{
      'title': form.title.trim(),
      'location': form.location.trim(),
      'description': form.description.trim(),
      'event_date': when.toUtc().toIso8601String(),
      'denomination': denomination,
      'church_id': churchId,
      'created_by': uid,
      'estado_verificacion': EstadoVerificacion.activo,
      'category': form.category.trim(),
      if (imageUrl != null) 'image_url': imageUrl,
    };

    try {
      final row = await _client.from('events').insert(payload).select(_select).single();
      return EventItem.fromJson(row);
    } catch (e) {
      payload.remove('category');
      payload.remove('image_url');
      final row = await _client.from('events').insert(payload).select().single();
      return EventItem.fromJson(row);
    }
  }
}
