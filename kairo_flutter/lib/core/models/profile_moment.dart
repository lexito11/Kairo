import 'package:flutter/material.dart';

import 'kairo_user.dart';
import 'story.dart';

class MomentIconStyle {
  const MomentIconStyle({
    required this.id,
    required this.icon,
    required this.color,
  });

  final String id;
  final IconData icon;
  final Color color;

  static const catalog = [
    MomentIconStyle(id: 'lightbulb', icon: Icons.lightbulb, color: Color(0xFFFBBF24)),
    MomentIconStyle(id: 'flight', icon: Icons.flight, color: Color(0xFFC4B5FD)),
    MomentIconStyle(id: 'headphones', icon: Icons.headphones, color: Color(0xFFF472B6)),
    MomentIconStyle(id: 'camera', icon: Icons.photo_camera, color: Color(0xFF38BDF8)),
    MomentIconStyle(id: 'radio', icon: Icons.radio, color: Color(0xFF60A5FA)),
    MomentIconStyle(id: 'favorite', icon: Icons.favorite, color: Color(0xFFF87171)),
    MomentIconStyle(id: 'menu_book', icon: Icons.menu_book, color: Color(0xFF7DD3FC)),
    MomentIconStyle(id: 'music_note', icon: Icons.music_note, color: Color(0xFFE879F9)),
    MomentIconStyle(id: 'church', icon: Icons.church, color: Color(0xFFFBBF24)),
    MomentIconStyle(id: 'star', icon: Icons.star, color: Color(0xFFFACC15)),
  ];

  static MomentIconStyle byId(String id) {
    return catalog.firstWhere(
      (e) => e.id == id,
      orElse: () => catalog.first,
    );
  }
}

class MomentItem {
  const MomentItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.storyId,
    this.createdAt,
  });

  final String id;
  final String mediaUrl;
  final String mediaType;
  final String? storyId;
  final DateTime? createdAt;

  bool get isVideo => mediaType == 'video';

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'storyId': storyId,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory MomentItem.fromJson(Map<String, dynamic> json) {
    return MomentItem(
      id: json['id'] as String? ?? '',
      mediaUrl: (json['mediaUrl'] ?? json['media_url']) as String? ?? '',
      mediaType: (json['mediaType'] ?? json['media_type']) as String? ?? 'image',
      storyId: (json['storyId'] ?? json['story_id']) as String?,
      createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at']) as String? ?? ''),
    );
  }
}

class ProfileMoment {
  const ProfileMoment({
    required this.id,
    required this.userId,
    required this.title,
    required this.iconId,
    required this.items,
    this.sortOrder = 0,
    this.coverImageUrl,
  });

  final String id;
  final String userId;
  final String title;
  final String iconId;
  final List<MomentItem> items;
  final int sortOrder;
  final String? coverImageUrl;

  MomentIconStyle get style => MomentIconStyle.byId(iconId);

  bool get hasPhotoCover => coverImageUrl != null && coverImageUrl!.isNotEmpty;

  ProfileMoment copyWith({
    String? title,
    String? iconId,
    List<MomentItem>? items,
    int? sortOrder,
    String? coverImageUrl,
    bool clearCover = false,
  }) {
    return ProfileMoment(
      id: id,
      userId: userId,
      title: title ?? this.title,
      iconId: iconId ?? this.iconId,
      items: items ?? this.items,
      sortOrder: sortOrder ?? this.sortOrder,
      coverImageUrl: clearCover ? null : (coverImageUrl ?? this.coverImageUrl),
    );
  }

  StoryGroup toStoryGroup(KairoUser author) {
    final now = DateTime.now();
    return StoryGroup(
      author: author,
      stories: [
        for (final item in items)
          Story(
            id: item.id,
            mediaUrl: item.mediaUrl,
            mediaType: item.mediaType,
            createdAt: item.createdAt ?? now,
            expiresAt: now.add(const Duration(days: 3650)),
            author: author,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'iconId': iconId,
        'coverImageUrl': coverImageUrl,
        'sortOrder': sortOrder,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory ProfileMoment.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return ProfileMoment(
      id: json['id'] as String? ?? '',
      userId: (json['userId'] ?? json['user_id']) as String? ?? '',
      title: json['title'] as String? ?? '',
      iconId: (json['iconId'] ?? json['icon_id']) as String? ?? 'star',
      coverImageUrl: (json['coverImageUrl'] ?? json['cover_url']) as String?,
      sortOrder: ((json['sortOrder'] ?? json['sort_order']) as num?)?.toInt() ?? 0,
      items: rawItems
          .whereType<Map>()
          .map((e) => MomentItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
