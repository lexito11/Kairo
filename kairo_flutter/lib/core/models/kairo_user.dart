class KairoUser {
  const KairoUser({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.image,
    this.bio,
    this.mood,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? image;
  final String? bio;
  final String? mood;
  final DateTime? createdAt;

  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final u = username?.trim();
    if (u != null && u.isNotEmpty) return u;
    final fromEmail = email.contains('@') ? email.split('@').first.trim() : email.trim();
    if (fromEmail.isNotEmpty) return fromEmail;
    return 'Usuario';
  }

  KairoUser copyWith({
    String? name,
    String? username,
    String? image,
    String? bio,
    String? mood,
  }) {
    return KairoUser(
      id: id,
      email: email,
      name: name ?? this.name,
      username: username ?? this.username,
      image: image ?? this.image,
      bio: bio ?? this.bio,
      mood: mood ?? this.mood,
      createdAt: createdAt,
    );
  }
  String get handle => username != null ? '@$username' : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'username': username,
        'image': image,
        'bio': bio,
        'mood': mood,
      };

  factory KairoUser.fromJson(Map<String, dynamic> json) {
    return KairoUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      username: json['username'] as String?,
      image: json['image'] as String?,
      bio: json['bio'] as String?,
      mood: json['mood'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
