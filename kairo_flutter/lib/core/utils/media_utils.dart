bool isVideoUrl(String url, {String? mediaType}) {
  if (mediaType == 'video') return true;
  final lower = url.toLowerCase();
  return lower.contains('.mp4') ||
      lower.contains('.webm') ||
      lower.contains('.mov') ||
      lower.contains('video') ||
      lower.contains('gtv-videos-bucket');
}

bool postHasVideo(PostLike post) {
  if (post.mediaType == 'video' && post.mediaUrl != null) return true;
  final urls = post.mediaUrls;
  if (urls != null) return urls.any((u) => isVideoUrl(u));
  if (post.mediaUrl != null) return isVideoUrl(post.mediaUrl!);
  return false;
}

abstract class PostLike {
  String? get mediaUrl;
  String? get mediaType;
  List<String>? get mediaUrls;
}

extension PostMedia on PostLike {
  List<MediaItem> get mediaItems {
    final items = <MediaItem>[];
    final urls = mediaUrls;
    if (urls != null && urls.isNotEmpty) {
      for (final url in urls) {
        items.add(MediaItem(url: url, isVideo: isVideoUrl(url, mediaType: mediaType)));
      }
    } else if (mediaUrl != null) {
      items.add(MediaItem(
        url: mediaUrl!,
        isVideo: isVideoUrl(mediaUrl!, mediaType: mediaType),
      ));
    }
    return items;
  }
}

class MediaItem {
  const MediaItem({required this.url, required this.isVideo});
  final String url;
  final bool isVideo;
}
