class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.location,
    required this.eventDate,
    this.description,
    this.denomination,
  });

  final String id;
  final String title;
  final String? location;
  final DateTime eventDate;
  final String? description;
  final String? denomination;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as String,
      title: json['title'] as String,
      location: json['location'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      description: json['description'] as String?,
      denomination: json['denomination'] as String?,
    );
  }
}
