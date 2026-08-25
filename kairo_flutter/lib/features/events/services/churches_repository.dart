import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/storage_service.dart';
import '../constants/church_countries.dart';
import '../models/church_application.dart';
import '../models/estado_verificacion.dart';
import '../models/event_data.dart';

class ChurchRecord {
  const ChurchRecord({
    required this.id,
    required this.name,
    required this.estadoVerificacion,
    required this.endorsementCount,
    required this.isSouthAmerica,
    this.motivoRechazo,
  });

  final String id;
  final String name;
  final String estadoVerificacion;
  final int endorsementCount;
  final bool isSouthAmerica;
  final String? motivoRechazo;

  bool get isActive => EstadoVerificacion.isActivo(estadoVerificacion);
  bool get isPending => EstadoVerificacion.isPendiente(estadoVerificacion);
  bool get isRejected => EstadoVerificacion.isRechazado(estadoVerificacion);

  factory ChurchRecord.fromMap(Map<String, dynamic> map) {
    final estado = map['estado_verificacion'] ?? map['status'];
    return ChurchRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      estadoVerificacion: EstadoVerificacion.normalize(estado as String?),
      endorsementCount: map['endorsement_count'] as int? ?? 0,
      isSouthAmerica: map['is_south_america'] as bool? ?? false,
      motivoRechazo: map['motivo_rechazo'] as String?,
    );
  }
}

class ChurchesRepository {
  ChurchesRepository({SupabaseClient? client, StorageService? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? StorageService();

  final SupabaseClient _client;
  final StorageService _storage;

  String? get _userId => _client.auth.currentUser?.id;

  static const _churchSelect = '''
    id, name, estado_verificacion, status, endorsement_count, is_south_america, motivo_rechazo
  ''';

  static const _applicationSelect = '''
    id, name, denomination, city, responsible_leader, pastor_email, country_name, country_code,
    is_south_america, fiscal_id, legal_document_url, facebook_url, instagram_url,
    estado_verificacion, status, motivo_rechazo, created_at,
    creator:users!churches_created_by_fkey(email, name)
  ''';

  Future<bool> hasRegisteredChurch() async {
    final uid = _userId;
    if (uid == null) return false;

    final row = await _client.from('churches').select('id').eq('created_by', uid).maybeSingle();
    return row != null;
  }

  Future<ChurchRecord?> getMyChurch() async {
    final uid = _userId;
    if (uid == null) return null;

    final row = await _client.from('churches').select(_churchSelect).eq('created_by', uid).maybeSingle();
    if (row == null) return null;
    return ChurchRecord.fromMap(row);
  }

  Future<bool> isCurrentUserAdmin() async {
    final uid = _userId;
    if (uid == null) return false;

    final row = await _client.from('users').select('is_admin').eq('id', uid).maybeSingle();
    return row?['is_admin'] == true;
  }

  Future<List<ChurchApplication>> fetchPendingApplications() async {
    final rows = await _client
        .from('churches')
        .select(_applicationSelect)
        .eq('estado_verificacion', EstadoVerificacion.pendiente)
        .order('created_at', ascending: false);

    return (rows as List).map((r) => ChurchApplication.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> reviewChurch(
    String churchId, {
    required bool approve,
    String? motivoRechazo,
  }) async {
    await _client.rpc('review_church', params: {
      'p_church_id': churchId,
      'p_action': approve ? 'approve' : 'reject',
      'p_motivo_rechazo': motivoRechazo,
    });
  }

  Future<ChurchRecord> registerChurch(ChurchFormData form) async {
    final uid = _userId;
    if (uid == null) {
      throw Exception('Debes iniciar sesión para registrar tu iglesia');
    }

    final error = form.validationError();
    if (error != null) throw Exception(error);

    final country = churchCountryByCode(form.countryCode);
    if (country == null) throw Exception('País no válido');

    final existing = await hasRegisteredChurch();
    if (existing) {
      throw Exception('Ya tienes una iglesia registrada');
    }

    String? legalDocumentUrl;
    if (form.isSouthAmerica) {
      if (form.legalDocumentBytes == null || form.legalDocumentName == null) {
        throw Exception('Sube la foto o PDF del documento legal');
      }
      legalDocumentUrl = await _storage.uploadBytes(
        bytes: form.legalDocumentBytes!,
        fileName: form.legalDocumentName!,
        mimeType: form.legalDocumentMime ?? 'application/octet-stream',
        subfolder: 'churches',
      );
    }

    final row = await _client.from('churches').insert({
      'name': form.name.trim(),
      'denomination': form.denomination,
      'city': form.city.trim(),
      'responsible_leader': form.responsibleLeader.trim(),
      'pastor_email': form.pastorEmail.trim().toLowerCase(),
      'country_code': country.code,
      'country_name': country.name,
      'is_south_america': country.isSouthAmerica,
      'fiscal_id': form.isSouthAmerica ? form.fiscalId.trim() : null,
      'legal_document_url': legalDocumentUrl,
      'facebook_url': form.facebookUrl.trim().isEmpty ? null : form.facebookUrl.trim(),
      'instagram_url': form.instagramUrl.trim().isEmpty ? null : form.instagramUrl.trim(),
      'created_by': uid,
      'estado_verificacion': EstadoVerificacion.pendiente,
      'status': 'pending',
    }).select(_churchSelect).single();

    return ChurchRecord.fromMap(row);
  }

  Future<void> endorseChurch(String churchId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Debes iniciar sesión');

    await _client.from('church_endorsements').insert({
      'church_id': churchId,
      'user_id': uid,
    });
  }
}
