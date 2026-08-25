import 'estado_verificacion.dart';

class ChurchApplication {
  const ChurchApplication({
    required this.id,
    required this.name,
    required this.denomination,
    required this.city,
    required this.responsibleLeader,
    required this.pastorEmail,
    required this.countryName,
    required this.countryCode,
    required this.isSouthAmerica,
    required this.estadoVerificacion,
    required this.createdAt,
    this.fiscalId,
    this.legalDocumentUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.creatorEmail,
    this.creatorName,
    this.motivoRechazo,
  });

  final String id;
  final String name;
  final String denomination;
  final String city;
  final String responsibleLeader;
  final String pastorEmail;
  final String countryName;
  final String countryCode;
  final bool isSouthAmerica;
  final String estadoVerificacion;
  final DateTime createdAt;
  final String? fiscalId;
  final String? legalDocumentUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? creatorEmail;
  final String? creatorName;
  final String? motivoRechazo;

  factory ChurchApplication.fromMap(Map<String, dynamic> map) {
    final creator = map['creator'] as Map<String, dynamic>?;
    final estado = map['estado_verificacion'] ?? map['status'];
    return ChurchApplication(
      id: map['id'] as String,
      name: map['name'] as String,
      denomination: map['denomination'] as String,
      city: map['city'] as String,
      responsibleLeader: map['responsible_leader'] as String? ?? '',
      pastorEmail: map['pastor_email'] as String? ?? '',
      countryName: map['country_name'] as String,
      countryCode: map['country_code'] as String,
      isSouthAmerica: map['is_south_america'] as bool? ?? false,
      estadoVerificacion: EstadoVerificacion.normalize(estado as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      fiscalId: map['fiscal_id'] as String?,
      legalDocumentUrl: map['legal_document_url'] as String?,
      facebookUrl: map['facebook_url'] as String?,
      instagramUrl: map['instagram_url'] as String?,
      creatorEmail: creator?['email'] as String?,
      creatorName: creator?['name'] as String?,
      motivoRechazo: map['motivo_rechazo'] as String?,
    );
  }
}
