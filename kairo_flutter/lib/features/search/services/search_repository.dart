import '../../../core/models/chat_group.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/post.dart';
import '../../../core/utils/media_utils.dart';
import '../../messages/services/groups_repository.dart';
import '../../posts/services/posts_repository.dart';
import '../../users/services/users_repository.dart';

class SearchTrend {
  const SearchTrend({required this.tag, required this.count});

  final String tag;
  final int count;

  String get postsLabel {
    if (count >= 1000) {
      final k = count / 1000;
      final label = k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return '${label}K publicaciones';
    }
    return count == 1 ? '1 publicación' : '$count publicaciones';
  }
}

class CommunitySearchResults {
  const CommunitySearchResults({
    required this.people,
    required this.posts,
    required this.videos,
    required this.groups,
    required this.peopleFirst,
    required this.followingIds,
  });

  final List<KairoUser> people;
  final List<Post> posts;
  final List<Post> videos;
  final List<ChatGroup> groups;
  final bool peopleFirst;
  final Set<String> followingIds;

  bool get isEmpty =>
      people.isEmpty && posts.isEmpty && videos.isEmpty && groups.isEmpty;

  static const empty = CommunitySearchResults(
    people: [],
    posts: [],
    videos: [],
    groups: [],
    peopleFirst: true,
    followingIds: {},
  );
}

class SearchRepository {
  SearchRepository({
    UsersRepository? users,
    PostsRepository? posts,
    GroupsRepository? groups,
  })  : _users = users ?? UsersRepository(),
        _posts = posts ?? PostsRepository(),
        _groups = groups ?? GroupsRepository();

  final UsersRepository _users;
  final PostsRepository _posts;
  final GroupsRepository _groups;

  static final _hashtagRe = RegExp(r'#([A-Za-zÁÉÍÓÚÜáéíóúüÑñ0-9_]{2,40})');
  static const _stopwords = {
    'para', 'como', 'esta', 'este', 'esto', 'estos', 'estas', 'porque',
    'desde', 'entre', 'sobre', 'todo', 'todos', 'todas', 'cuando', 'donde',
    'tiene', 'tengo', 'somos', 'estamos', 'nuestra', 'nuestro', 'nuestros',
    'con', 'los', 'las', 'del', 'una', 'uno', 'por', 'que', 'más', 'mas',
    'dios',
  };

  Future<CommunitySearchResults> search(String rawQuery) async {
    final raw = rawQuery.trim();
    final query = raw.replaceAll('#', '').trim().toLowerCase();
    if (query.length < 2) return CommunitySearchResults.empty;

    final peopleFuture = _users.searchUsers(raw.replaceAll('#', ' ').trim());
    final postsFuture = _posts.searchPosts(raw);
    final groupsFuture = _groups.searchGroups(raw);
    final followingFuture = _users.fetchFollowingIds();

    final people = await peopleFuture;
    final contentPosts = await postsFuture;
    final authorPosts = await _posts.fetchPostsByAuthorIds(
      people.map((u) => u.id).toList(),
    );

    final byId = <String, Post>{};
    for (final post in [...contentPosts, ...authorPosts]) {
      byId[post.id] = post;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final videos = merged.where(postHasVideo).toList();
    final imagesOrText = merged.where((p) => !postHasVideo(p)).toList();
    List<ChatGroup> groups = const [];
    try {
      groups = await groupsFuture;
    } catch (_) {}
    final followingIds = await followingFuture;

    final topic = raw.startsWith('#');
    final peoplePriority = !topic &&
        people.any((p) {
          final name = p.displayName.toLowerCase();
          final handle = (p.username ?? '').toLowerCase();
          return name.contains(query) ||
              handle.contains(query) ||
              name.split(RegExp(r'\s+')).any((part) => part.startsWith(query));
        });

    return CommunitySearchResults(
      people: people,
      posts: imagesOrText,
      videos: videos,
      groups: groups,
      peopleFirst: peoplePriority,
      followingIds: followingIds,
    );
  }

  Future<List<SearchTrend>> fetchTrends({int limit = 10}) async {
    try {
      final contents = await _posts.fetchRecentPostContents();
      final counts = <String, int>{};

      for (final content in contents) {
        final tags = _hashtagRe.allMatches(content).map((m) => m.group(1)!).toList();
        if (tags.isNotEmpty) {
          for (final tag in tags) {
            final key = tag.toLowerCase();
            counts[key] = (counts[key] ?? 0) + 1;
          }
          continue;
        }
        for (final word in _topicWords(content)) {
          counts[word] = (counts[word] ?? 0) + 1;
        }
      }

      final ranked = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return ranked.take(limit).map((e) {
        final raw = e.key;
        final pretty = raw[0].toUpperCase() + raw.substring(1);
        return SearchTrend(tag: '#$pretty', count: e.value);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<KairoUser>> fetchSuggestedPeople() {
    return _users.fetchSuggestedUsers();
  }

  Future<List<Post>> fetchRecentPosts({int limit = 20}) {
    return _posts.fetchRecentPublicPosts(limit: limit);
  }

  Future<Set<String>> fetchFollowingIds() {
    return _users.fetchFollowingIds();
  }

  Future<void> toggleFollow(String userId, {required bool following}) {
    return following ? _users.unfollow(userId) : _users.follow(userId);
  }

  Iterable<String> _topicWords(String content) {
    return content
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-záéíóúüñ0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !_stopwords.contains(w));
  }
}
