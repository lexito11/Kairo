import 'dart:typed_data';

import '../constants/church_countries.dart';

class EventData {
  const EventData({
    required this.id,
    required this.title,
    required this.church,
    required this.location,
    required this.date,
    required this.time,
    required this.category,
    required this.denomination,
    required this.image,
    required this.isLive,
    required this.description,
    this.distance,
  });

  final String id;
  final String title;
  final String church;
  final String location;
  final DateTime date;
  final String time;
  final String category;
  final String denomination;
  final String image;
  final bool isLive;
  final String description;
  final int? distance;

  bool get isToday {
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return eventDate == todayDate;
  }

  bool get isFuture {
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return eventDate.isAfter(todayDate);
  }
}

enum EventFilterType { todos, hoy, enVivo, proximos }

enum EventScope { cristianos, iglesia }

enum AttendanceStatus { attending, notAttending }

class AttendanceInfo {
  const AttendanceInfo({
    this.attending = 0,
    this.notAttending = 0,
    this.userStatus,
  });

  final int attending;
  final int notAttending;
  final AttendanceStatus? userStatus;

  AttendanceInfo copyWith({
    int? attending,
    int? notAttending,
    AttendanceStatus? userStatus,
    bool clearUserStatus = false,
  }) {
    return AttendanceInfo(
      attending: attending ?? this.attending,
      notAttending: notAttending ?? this.notAttending,
      userStatus: clearUserStatus ? null : (userStatus ?? this.userStatus),
    );
  }
}

class ChurchFormData {
  const ChurchFormData({
    this.name = '',
    this.denomination = '',
    this.city = '',
    this.countryCode = '',
    this.responsibleLeader = '',
    this.password = '',
    this.fiscalId = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.legalDocumentBytes,
    this.legalDocumentName,
    this.legalDocumentMime,
  });

  final String name;
  final String denomination;
  final String city;
  final String countryCode;
  final String responsibleLeader;
  final String password;
  final String fiscalId;
  final String facebookUrl;
  final String instagramUrl;
  final Uint8List? legalDocumentBytes;
  final String? legalDocumentName;
  final String? legalDocumentMime;

  bool get isSouthAmerica => isSouthAmericaCountry(countryCode);

  bool get hasLegalDocument =>
      legalDocumentBytes != null && legalDocumentBytes!.isNotEmpty;

  bool get hasFacebook => _isValidFacebookUrl(facebookUrl);

  bool get hasInstagram => _isValidInstagramUrl(instagramUrl);

  bool get isValid {
    if (name.trim().isEmpty ||
        denomination.isEmpty ||
        city.trim().isEmpty ||
        countryCode.isEmpty ||
        responsibleLeader.trim().isEmpty ||
        password.length < 6) {
      return false;
    }

    if (isSouthAmerica) {
      return fiscalId.trim().isNotEmpty &&
          hasLegalDocument &&
          hasFacebook &&
          hasInstagram;
    }

    return hasFacebook || hasInstagram;
  }

  String? validationError() {
    if (name.trim().isEmpty) return 'Ingresa el nombre de la iglesia';
    if (denomination.isEmpty) return 'Selecciona una denominación';
    if (city.trim().isEmpty) return 'Ingresa la ciudad';
    if (countryCode.isEmpty) return 'Selecciona un país';
    if (responsibleLeader.trim().isEmpty) return 'Ingresa el pastor o líder responsable';
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres';

    if (isSouthAmerica) {
      if (fiscalId.trim().isEmpty) {
        return 'Ingresa el identificador fiscal';
      }
      if (!hasLegalDocument) {
        return 'Sube la foto o PDF del documento legal';
      }
      if (!hasFacebook) return 'Ingresa un enlace válido de Facebook';
      if (!hasInstagram) return 'Ingresa un enlace válido de Instagram';
      return null;
    }

    if (!hasFacebook && !hasInstagram) {
      return 'Ingresa al menos un enlace de Facebook o Instagram';
    }
    if (facebookUrl.trim().isNotEmpty && !hasFacebook) {
      return 'El enlace de Facebook no es válido';
    }
    if (instagramUrl.trim().isNotEmpty && !hasInstagram) {
      return 'El enlace de Instagram no es válido';
    }
    return null;
  }

  ChurchFormData copyWith({
    String? name,
    String? denomination,
    String? city,
    String? countryCode,
    String? responsibleLeader,
    String? password,
    String? fiscalId,
    String? facebookUrl,
    String? instagramUrl,
    Uint8List? legalDocumentBytes,
    String? legalDocumentName,
    String? legalDocumentMime,
    bool clearLegalDocument = false,
  }) {
    return ChurchFormData(
      name: name ?? this.name,
      denomination: denomination ?? this.denomination,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
      responsibleLeader: responsibleLeader ?? this.responsibleLeader,
      password: password ?? this.password,
      fiscalId: fiscalId ?? this.fiscalId,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      legalDocumentBytes: clearLegalDocument ? null : (legalDocumentBytes ?? this.legalDocumentBytes),
      legalDocumentName: clearLegalDocument ? null : (legalDocumentName ?? this.legalDocumentName),
      legalDocumentMime: clearLegalDocument ? null : (legalDocumentMime ?? this.legalDocumentMime),
    );
  }

  static const empty = ChurchFormData();

  static bool _isValidFacebookUrl(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    return trimmed.contains('facebook.com') || trimmed.contains('fb.com');
  }

  static bool _isValidInstagramUrl(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    return trimmed.contains('instagram.com');
  }
}
