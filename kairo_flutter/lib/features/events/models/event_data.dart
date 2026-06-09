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
    this.password = '',
  });

  final String name;
  final String denomination;
  final String city;
  final String password;

  ChurchFormData copyWith({
    String? name,
    String? denomination,
    String? city,
    String? password,
  }) {
    return ChurchFormData(
      name: name ?? this.name,
      denomination: denomination ?? this.denomination,
      city: city ?? this.city,
      password: password ?? this.password,
    );
  }

  static const empty = ChurchFormData();
}
