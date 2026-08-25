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
    this.pastorEmail = '',
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
  final String pastorEmail;
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
        !_isValidEmail(pastorEmail) ||
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
    if (pastorEmail.trim().isEmpty) return 'Ingresa el correo del pastor';
    if (!_isValidEmail(pastorEmail)) return 'Ingresa un correo del pastor válido';
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
    String? pastorEmail,
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
      pastorEmail: pastorEmail ?? this.pastorEmail,
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

  static bool _isValidEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

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

class EventRequestFormData {
  const EventRequestFormData({
    this.title = '',
    this.location = '',
    this.description = '',
    this.category = '',
    this.date,
    this.time = '',
  });

  final String title;
  final String location;
  final String description;
  final String category;
  final DateTime? date;
  final String time;

  bool get isValid =>
      title.trim().isNotEmpty &&
      location.trim().isNotEmpty &&
      description.trim().isNotEmpty &&
      category.isNotEmpty &&
      date != null &&
      time.trim().isNotEmpty;

  String? validationError() {
    if (title.trim().isEmpty) return 'Ingresa el título del evento';
    if (location.trim().isEmpty) return 'Ingresa la ubicación';
    if (description.trim().isEmpty) return 'Ingresa una descripción';
    if (category.isEmpty) return 'Selecciona el tipo de evento';
    if (date == null) return 'Selecciona la fecha';
    if (time.trim().isEmpty) return 'Ingresa la hora (ej. 19:00)';
    return null;
  }

  DateTime? get eventDateTime {
    if (date == null) return null;
    final parts = time.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(date!.year, date!.month, date!.day, hour, minute);
  }

  EventRequestFormData copyWith({
    String? title,
    String? location,
    String? description,
    String? category,
    DateTime? date,
    String? time,
  }) {
    return EventRequestFormData(
      title: title ?? this.title,
      location: location ?? this.location,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
    );
  }

  static const empty = EventRequestFormData();
}
