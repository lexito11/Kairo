import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/event_item.dart';

class EventsRepository {
  EventsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<EventItem>> fetchUpcoming({String? denomination}) async {
    var query = _client
        .from('events')
        .select()
        .gte('event_date', DateTime.now().toIso8601String())
        .order('event_date', ascending: true)
        .limit(50);

    final rows = await query;
    var list = (rows as List).map((r) => EventItem.fromJson(r as Map<String, dynamic>)).toList();

    if (denomination != null && denomination.isNotEmpty && denomination != 'general') {
      list = list.where((e) => e.denomination == null || e.denomination == denomination || e.denomination == 'general').toList();
    }
    return list;
  }
}
