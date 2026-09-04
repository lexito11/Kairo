class KairoUser {
  const KairoUser({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.image,
    this.coverUrl,
    this.bio,
    this.mood,
    this.moodUpdatedAt,
    this.createdAt,
    this.usernameChangedAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? image;
  final String? coverUrl;
  final String? bio;
  final String? mood;
  final DateTime? moodUpdatedAt;
  final DateTime? createdAt;
  final DateTime? usernameChangedAt;

  static const moodLockDuration = Duration(hours: 24);

  bool get hasActiveMood {
    final value = mood?.trim();
    if (value == null || value.isEmpty || moodUpdatedAt == null) return false;
    return DateTime.now().toUtc().difference(moodUpdatedAt!.toUtc()) < moodLockDuration;
  }

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
    String? coverUrl,
    String? bio,
    String? mood,
    DateTime? moodUpdatedAt,
    DateTime? usernameChangedAt,
  }) {
    return KairoUser(
      id: id,
      email: email,
      name: name ?? this.name,
      username: username ?? this.username,
      image: image ?? this.image,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      mood: mood ?? this.mood,
      moodUpdatedAt: moodUpdatedAt ?? this.moodUpdatedAt,
      createdAt: createdAt,
      usernameChangedAt: usernameChangedAt ?? this.usernameChangedAt,
    );
  }
  String get handle => username != null ? '@$username' : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'username': username,
        'image': image,
        'coverUrl': coverUrl,
        'bio': bio,
        'mood': mood,
        'mood_updated_at': moodUpdatedAt?.toIso8601String(),
      };

  factory KairoUser.fromJson(Map<String, dynamic> json) {
    String? text(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    DateTime? date(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return KairoUser(
      id: json['id'].toString(),
      email: json['email'] as String? ?? '',
      name: text(json['name']),
      username: text(json['username']),
      image: text(json['image']) ?? text(json['avatar_url']),
      coverUrl: text(json['cover_url']) ?? text(json['coverUrl']),
      bio: text(json['bio']),
      mood: text(json['mood']),
      moodUpdatedAt: date(json['mood_updated_at']),
      createdAt: date(json['created_at']),
      usernameChangedAt: date(json['username_changed_at']),
    );
  }
}
