import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../core/providers/social_summary_provider.dart';
import '../../posts/services/posts_repository.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../../posts/widgets/post_card.dart';
import '../../users/services/users_repository.dart';
import '../widgets/feelings_selector.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key, this.userId});

  final String? userId;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _usersRepo = UsersRepository();
  final _postsRepo = PostsRepository();
  final _prefs = PrefsService();

  UserProfileData? _profile;
  List<Post> _posts = [];
  List<Post> _savedPosts = [];
  String _tab = 'publicaciones';
  bool _loading = true;
  bool _followLoading = false;
  bool _changingPhoto = false;

  String? get _viewedUserId => widget.userId ?? AuthService().currentUser?.id;
  bool get _isOwner => widget.userId == null || widget.userId == AuthService().currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _viewedUserId;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final profile = await _usersRepo.getUserProfile(uid);
      final posts = await _postsRepo.fetchUserPosts(uid);
      if (_isOwner) {
        final summary = await _usersRepo.getSocialSummary();
        if (mounted) {
          context.read<SocialSummaryProvider>().update(
                unread: summary.unreadCount,
                friends: summary.friendsCount,
              );
        }
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _posts = posts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSaved() async {
    final ids = await _prefs.getSavedPostIds();
    if (ids.isEmpty) {
      setState(() => _savedPosts = []);
      return;
    }
    final posts = await _postsRepo.fetchPostsByIds(ids);
    setState(() => _savedPosts = posts);
  }

  Future<void> _changePhoto() async {
    if (!_isOwner || _changingPhoto) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _changingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await StorageService().uploadBytes(
        bytes: bytes,
        fileName: file.name,
        mimeType: 'image/jpeg',
        subfolder: 'avatars',
      );
      await _usersRepo.updateProfile(image: url);
      if (!mounted) return;
      final current = _profile;
      if (current != null) {
        setState(() => _profile = current.copyWith(user: current.user.copyWith(image: url)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la foto de perfil')),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  Widget _profileAvatar() {
    final user = _profile?.user;
    final name = user?.displayName ?? 'Usuario';
    final hasMood = (user?.mood ?? '').trim().isNotEmpty;
    final avatar = KairoAvatar(imageUrl: user?.image, name: name, size: 88);

    Widget photo = avatar;
    if (hasMood) {
      photo = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: KairoColors.primary500, width: 2.5),
        ),
        child: avatar,
      );
    }

    if (!_isOwner) return photo;

    return GestureDetector(
      onTap: _changingPhoto ? null : _changePhoto,
      child: SizedBox(
        width: hasMood ? 104 : 96,
        height: hasMood ? 104 : 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            photo,
            if (_changingPhoto)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
              ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: KairoColors.primary500,
                  shape: BoxShape.circle,
                  border: Border.all(color: KairoColors.darkBg, width: 2),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isOwner) return;
    setState(() => _followLoading = true);
    try {
      if (_profile!.viewerHasAdded) {
        await _usersRepo.unfollow(_profile!.user.id);
      } else {
        await _usersRepo.follow(_profile!.user.id);
      }
      await _load();
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _updatePostContent(String postId, String content) async {
    await _postsRepo.updatePostContent(postId, content);
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) _posts[idx] = _posts[idx].copyWith(content: content);
    });
  }

  Future<void> _deletePost(String postId) async {
    await _postsRepo.deletePost(postId);
    setState(() => _posts.removeWhere((p) => p.id == postId));
  }

  List<Post> get _displayPosts {
    switch (_tab) {
      case 'guardados':
        return _savedPosts;
      default:
        return _posts;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isSignedIn && widget.userId == null) {
      return MainScaffold(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Inicia sesión para ver tu perfil', style: TextStyle(color: KairoColors.darkTextSecondary)),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/auth/signin'), child: const Text('Iniciar sesión')),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const MainScaffold(child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)));
    }

    final user = _profile?.user;
    final tabs = _isOwner
        ? ['publicaciones', 'guardados']
        : ['publicaciones'];

    return MainScaffold(
      child: RefreshIndicator(
        color: KairoColors.primary500,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: KairoColors.darkBg,
              title: Text(_isOwner ? 'Mi perfil' : user?.displayName ?? 'Perfil'),
              actions: [
                if (_isOwner)
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => context.push('/notifications'),
                      ),
                      if ((context.watch<SocialSummaryProvider>().unreadCount) > 0)
                        Positioned(
                          right: 10, top: 10,
                          child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: KairoColors.primary500, shape: BoxShape.circle)),
                        ),
                    ],
                  ),
                if (_isOwner)
                  IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _profileAvatar(),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? 'Usuario',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (user?.username != null)
                      Text('@${user!.username}', style: const TextStyle(color: KairoColors.darkTextSecondary)),
                    if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(user.bio!, textAlign: TextAlign.center, style: const TextStyle(color: KairoColors.darkTextSecondary)),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(label: 'Agregados', value: '${_profile?.agregados ?? 0}'),
                        _Stat(label: 'Te agregaron', value: '${_profile?.teAgregaron ?? 0}'),
                        if (_isOwner) _Stat(label: 'Amigos', value: '${_profile?.friendsCount ?? 0}'),
                      ],
                    ),
                    if (_isOwner) ...[
                      const SizedBox(height: 20),
                      FeelingsSelector(
                        currentMood: user?.mood,
                        onChanged: (mood) {
                          final current = _profile;
                          if (current == null) return;
                          setState(() {
                            _profile = current.copyWith(user: current.user.copyWith(mood: mood));
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_isOwner && _profile != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _followLoading ? null : _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _profile!.viewerHasAdded ? KairoColors.darkHover : KairoColors.primary500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_profile!.viewerHasAdded ? 'Agregado' : 'Agregar'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Row(
                children: tabs.map((t) {
                  final labels = {'publicaciones': 'Publicaciones', 'guardados': 'Guardados'};
                  final active = _tab == t;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _tab = t);
                        if (t == 'guardados') _loadSaved();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: active ? KairoColors.primary500 : Colors.transparent, width: 2)),
                        ),
                        child: Text(
                          labels[t] ?? t,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: active ? KairoColors.primary400 : KairoColors.darkTextSecondary,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: _displayPosts.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('Sin publicaciones', style: TextStyle(color: KairoColors.darkTextSecondary))),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final post = _displayPosts[i];
                          final uid = AuthService().currentUser?.id;
                          final isPostOwner = uid != null && post.author.id == uid;
                          return PostCard(
                            post: post,
                            isOwner: isPostOwner,
                            onComment: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CommentsSheet(postId: post.id),
                            ),
                            onEditContent: (content) => _updatePostContent(post.id, content),
                            onDeleteText: () => _updatePostContent(post.id, ''),
                            onDeletePost: () => _deletePost(post.id),
                          );
                        },
                        childCount: _displayPosts.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
      ],
    );
  }
}
