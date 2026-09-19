import 'package:supabase_flutter/supabase_flutter.dart';

enum ReportTargetType { post, comment, user, group, event, message, live, story }

enum ReportReason {
  sexual,
  nudity,
  bikini,
  underwear,
  sexualPromotion,
  discrimination,
  bullying,
  harassment,
  threats,
  severeInsult,
}

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
        ReportReason.sexual => 'Contenido sexual',
        ReportReason.nudity => 'Desnudez',
        ReportReason.bikini => 'Personas en bikini',
        ReportReason.underwear => 'Personas en ropa interior',
        ReportReason.sexualPromotion => 'Promoción de contenido sexual',
        ReportReason.discrimination => 'Discriminación',
        ReportReason.bullying => 'Bullying',
        ReportReason.harassment => 'Acoso u hostigamiento',
        ReportReason.threats => 'Amenazas',
        ReportReason.severeInsult => 'Insulto gravemente degradante',
      };

  String get apiValue => name;
}

class ReportsRepository {
  ReportsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> submit({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Debes iniciar sesión');

    try {
      await _client.from('content_reports').insert({
        'reporter_id': uid,
        'target_type': targetType.name,
        'target_id': targetId,
        'reason': reason.apiValue,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Ya reportaste este contenido.');
      }
      rethrow;
    }
  }
}
