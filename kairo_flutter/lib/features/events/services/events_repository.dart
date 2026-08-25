import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/event_item.dart';
import '../models/estado_verificacion.dart';
import '../models/event_data.dart';

class EventsRepository {
  EventsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<EventItem>> fetchUpcoming({String? denomination}) async {
    var query = _client
        .from('events')
        .select()
        .eq('estado_verificacion', EstadoVerificacion.activo)
        .gte('event_date', DateTime.now().toIso8601String())
        .order('event_date', ascending: true)
        .limit(50);

    final rows = await query;
    var list = (rows as List).map((r) => EventItem.fromJson(r as Map<String, dynamic>)).toList();

    if (denomination != null && denomination.isNotEmpty && denomination != 'general') {
      list = list
          .where((e) => e.denomination == null || e.denomination == denomination || e.denomination == 'general')
          .toList();
    }
    return list;
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

    final when = form.eventDateTime;
    if (when == null) throw Exception('Fecha u hora no válidas');

    final description = form.category.trim().isEmpty
        ? form.description.trim()
        : '${form.category.trim()}\n\n${form.description.trim()}';

    final row = await _client.from('events').insert({
      'title': form.title.trim(),
      'location': form.location.trim(),
      'description': description,
      'event_date': when.toUtc().toIso8601String(),
      'denomination': denomination,
      'church_id': churchId,
      'created_by': uid,
      'estado_verificacion': EstadoVerificacion.pendiente,
    }).select().single();

    return EventItem.fromJson(row);
  }
}
