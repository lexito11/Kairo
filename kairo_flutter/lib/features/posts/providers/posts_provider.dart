import 'package:flutter/foundation.dart';
import '../../../core/models/post.dart';
import '../services/posts_repository.dart';

class PostsProvider extends ChangeNotifier {
  PostsProvider({PostsRepository? repo}) : _repo = repo ?? PostsRepository();

  final PostsRepository _repo;

  final List<Post> _posts = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  bool _videoOnly = false;

  List<Post> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadFeed({bool refresh = false, bool videoOnly = false}) async {
    if (_loading) return;
    if (_videoOnly != videoOnly) refresh = true;
    _videoOnly = videoOnly;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _posts.clear();
    }
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final batch = await _repo.fetchFeed(page: _page, limit: 20, videoOnly: videoOnly);
      if (refresh) _posts.clear();
      _posts.addAll(batch);
      _hasMore = batch.length >= 20;
      if (batch.isNotEmpty) _page++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final batch = await _repo.fetchFeed(page: _page, limit: 20, videoOnly: _videoOnly);
      _posts.addAll(batch);
      _hasMore = batch.length >= 20;
      if (batch.isNotEmpty) _page++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = _posts[idx];
    _posts[idx] = post.copyWith(
      isLiked: !post.isLiked,
      likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
    );
    notifyListeners();
    try {
      final liked = await _repo.toggleLike(postId);
      _posts[idx] = post.copyWith(
        isLiked: liked,
        likesCount: liked ? post.likesCount + (post.isLiked ? 0 : 1) : post.likesCount - (post.isLiked ? 1 : 0),
      );
      notifyListeners();
    } catch (_) {
      _posts[idx] = post;
      notifyListeners();
    }
  }

  Future<Post> createPost({
    required String content,
    PostKind postKind = PostKind.post,
    bool isAnonymous = false,
    List<({Uint8List bytes, String name, String mime})>? files,
  }) {
    return _repo.createPost(
      content: content,
      postKind: postKind,
      isAnonymous: isAnonymous,
      files: files,
    );
  }

  Future<void> toggleIntercede(String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = _posts[idx];
    if (!post.isPrayer || post.hasInterceded) return;
    _posts[idx] = post.copyWith(
      hasInterceded: true,
      intercessionsCount: post.intercessionsCount + 1,
    );
    notifyListeners();
    try {
      await _repo.toggleIntercede(postId);
    } catch (_) {
      _posts[idx] = post;
      notifyListeners();
    }
  }

  void incrementCommentCount(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = _posts[idx];
    _posts[idx] = post.copyWith(commentsCount: post.commentsCount + 1);
    notifyListeners();
  }

  Future<void> updatePostContent(String postId, String content) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final previous = _posts[idx];
    _posts[idx] = previous.copyWith(content: content);
    notifyListeners();
    try {
      final updated = await _repo.updatePostContent(postId, content);
      _posts[idx] = updated;
      notifyListeners();
    } catch (_) {
      _posts[idx] = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final removed = _posts.removeAt(idx);
    notifyListeners();
    try {
      await _repo.deletePost(postId);
    } catch (_) {
      _posts.insert(idx, removed);
      notifyListeners();
      rethrow;
    }
  }
}
