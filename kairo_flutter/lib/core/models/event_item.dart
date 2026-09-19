class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.location,
    required this.eventDate,
    this.description,
    this.denomination,
    this.category,
    this.imageUrl,
    this.churchName,
    this.churchId,
    this.createdBy,
    this.estadoVerificacion = 'activo',
  });

  final String id;
  final String title;
  final String? location;
  final DateTime eventDate;
  final String? description;
  final String? denomination;
  final String? category;
  final String? imageUrl;
  final String? churchName;
  final String? churchId;
  final String? createdBy;
  final String estadoVerificacion;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    final churchRaw = json['church'];
    final church = churchRaw is Map ? Map<String, dynamic>.from(churchRaw) : null;
    return EventItem(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Evento',
      location: json['location'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String).toLocal(),
      description: json['description'] as String?,
      denomination: json['denomination'] as String?,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      churchName: church?['name'] as String?,
      churchId: json['church_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      estadoVerificacion: json['estado_verificacion'] as String? ?? 'activo',
    );
  }
}
