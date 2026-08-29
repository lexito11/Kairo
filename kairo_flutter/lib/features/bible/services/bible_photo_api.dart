import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/image_api_config.dart';
import '../models/bible_photo.dart';
import 'bible_photo_fallbacks.dart';

class BiblePhotoApi {
  BiblePhotoApi._();
  static final BiblePhotoApi instance = BiblePhotoApi._();

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'KAIRO/1.0 (Flutter; Bible image editor)',
  };

  final Map<BiblePhotoCategory, List<BiblePhoto>> _cache = {};

  Future<List<BiblePhoto>> fetch(BiblePhotoCategory category, {bool force = false}) async {
    if (!force) {
      final cached = _cache[category];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    List<BiblePhoto> photos = const [];
    if (ImageApiConfig.hasUnsplash) {
      try {
        photos = await _fetchUnsplash(category);
      } catch (_) {}
    }
    if (photos.isEmpty && ImageApiConfig.hasPexels) {
      try {
        photos = await _fetchPexels(category);
      } catch (_) {}
    }
    if (photos.isEmpty) {
      photos = BiblePhotoFallbacks.forCategory(category);
    }

    _cache[category] = photos;
    return photos;
  }

  Future<void> trackDownload(BiblePhoto photo) async {
    final location = photo.downloadLocation;
    if (location == null || location.isEmpty || !ImageApiConfig.hasUnsplash) return;
    try {
      await http
          .get(
            Uri.parse(location),
            headers: {
              ..._headers,
              'Authorization': 'Client-ID ${ImageApiConfig.unsplashAccessKey}',
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<List<BiblePhoto>> _fetchUnsplash(BiblePhotoCategory category) async {
    final uri = Uri.https('api.unsplash.com', '/search/photos', {
      'query': category.query,
      'per_page': '18',
      'orientation': 'landscape',
      'content_filter': 'high',
    });
    final res = await http
        .get(
          uri,
          headers: {
            ..._headers,
            'Authorization': 'Client-ID ${ImageApiConfig.unsplashAccessKey}',
            'Accept-Version': 'v1',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Unsplash ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? const [];
    return results.map((raw) {
      final item = raw as Map<String, dynamic>;
      final urls = item['urls'] as Map<String, dynamic>? ?? const {};
      final user = item['user'] as Map<String, dynamic>? ?? const {};
      final links = item['links'] as Map<String, dynamic>? ?? const {};
      return BiblePhoto(
        id: '${item['id']}',
        thumbUrl: (urls['small'] as String?) ?? (urls['thumb'] as String?) ?? '',
        fullUrl: (urls['regular'] as String?) ?? (urls['full'] as String?) ?? '',
        photographer: (user['name'] as String?) ?? 'Unsplash',
        downloadLocation: links['download_location'] as String?,
        source: 'unsplash',
      );
    }).where((p) => p.fullUrl.isNotEmpty).toList();
  }

  Future<List<BiblePhoto>> _fetchPexels(BiblePhotoCategory category) async {
    final uri = Uri.https('api.pexels.com', '/v1/search', {
      'query': category.query,
      'per_page': '18',
      'orientation': 'landscape',
    });
    final res = await http
        .get(
          uri,
          headers: {
            ..._headers,
            'Authorization': ImageApiConfig.pexelsApiKey,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Pexels ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final results = data['photos'] as List<dynamic>? ?? const [];
    return results.map((raw) {
      final item = raw as Map<String, dynamic>;
      final src = item['src'] as Map<String, dynamic>? ?? const {};
      return BiblePhoto(
        id: 'pexels-${item['id']}',
        thumbUrl: (src['medium'] as String?) ?? (src['tiny'] as String?) ?? '',
        fullUrl: (src['large'] as String?) ?? (src['landscape'] as String?) ?? '',
        photographer: (item['photographer'] as String?) ?? 'Pexels',
        source: 'pexels',
      );
    }).where((p) => p.fullUrl.isNotEmpty).toList();
  }
}
