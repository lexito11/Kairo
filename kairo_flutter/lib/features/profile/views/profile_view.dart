import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/post.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../../core/providers/social_summary_provider.dart';
import '../../posts/services/posts_repository.dart';
import '../../posts/widgets/share_sheet.dart';
import '../../stories/services/stories_repository.dart';
import '../../users/services/users_repository.dart';
import '../widgets/feelings_selector.dart';
import '../widgets/moments_strip.dart';
import '../widgets/profile_gallery_viewer.dart';
import '../widgets/profile_posts_grid.dart';
import '../widgets/profile_text_list.dart';
import 'cover_crop_view.dart';


class ProfileView extends StatefulWidget {
  const ProfileView({super.key, this.userId});

  final String? userId;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with RouteAware {
  final _usersRepo = UsersRepository();
  final _postsRepo = PostsRepository();
  final _prefs = PrefsService();

  UserProfileData? _profile;
  List<Post> _posts = [];
  List<Post> _savedPosts = [];
  String _tab = 'publicaciones';
  bool _loading = true;
  bool _followLoading = false;
  bool _publishingStory = false;
  bool _changingCover = false;
  bool _hasActiveStory = false;
  bool _subscribed = false;

  String? get _viewedUserId => widget.userId ?? AuthService().currentUser?.id;
  bool get _isOwner => widget.userId == null || widget.userId == AuthService().currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void didPopNext() {
    _load();
  }

  @override
  void dispose() {
    if (_subscribed) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _viewedUserId;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    if (_profile == null) {
      setState(() => _loading = true);
    }
    try {
      var profile = await _usersRepo.getUserProfile(uid);
      if (_isOwner) {
        try {
          profile = profile.copyWith(user: await _usersRepo.ensureGeneratedUsername(profile.user));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      try {
        final me = await _usersRepo.getCurrentUser();
        if (me != null && _isOwner && mounted) {
          setState(() {
            _profile = UserProfileData(
              user: me,
              agregados: 0,
              teAgregaron: 0,
              viewerHasAdded: false,
            );
            _loading = false;
          });
        } else if (mounted) {
          setState(() => _loading = false);
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }

    try {
      final posts = await _postsRepo.fetchUserPosts(uid);
      if (mounted) setState(() => _posts = posts);
    } catch (_) {}

    try {
      final hasStory = await StoriesRepository().hasActiveStories(uid);
      if (mounted) setState(() => _hasActiveStory = hasStory);
    } catch (_) {}

    if (!_isOwner) return;
    try {
      final summary = await _usersRepo.getSocialSummary();
      if (mounted) {
        context.read<SocialSummaryProvider>().update(
              unread: summary.unreadCount,
              friends: summary.friendsCount,
            );
      }
    } catch (_) {}
    try {
      final ids = await _prefs.getSavedPostIds();
      final saved = ids.isEmpty ? <Post>[] : await _postsRepo.fetchPostsByIds(ids);
      if (mounted) setState(() => _savedPosts = saved);
    } catch (_) {}
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

  Future<void> _addStoryFromAvatar() async {
    if (!_isOwner || _publishingStory) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _publishingStory = true);
    try {
      final bytes = await file.readAsBytes();
      await StoriesRepository().publishStory(
        bytes: bytes,
        fileName: file.name,
        mimeType: 'image/jpeg',
      );
      if (!mounted) return;
      setState(() => _hasActiveStory = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historia publicada')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo publicar la historia')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishingStory = false);
    }
  }

  Future<void> _changeCover() async {
    if (!_isOwner || _changingCover) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null || !mounted) return;
    final original = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await showCoverCropper(context, original);
    if (cropped == null || cropped.isEmpty || !mounted) return;
    setState(() => _changingCover = true);
    try {
      final url = await StorageService().uploadBytes(
        bytes: cropped,
        fileName: 'cover.png',
        mimeType: 'image/png',
        subfolder: 'covers',
      );
      await _usersRepo.updateProfile(coverUrl: url);
      if (!mounted) return;
      final current = _profile;
      if (current != null) {
        setState(() => _profile = current.copyWith(user: current.user.copyWith(coverUrl: url)));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portada actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _changingCover = false);
    }
  }

  Widget _profileHero() {
    final user = _profile?.user;
    final name = user?.displayName ?? 'Usuario';
    final handle = user?.username != null && user!.username!.isNotEmpty
        ? '@${user.username}'
        : '@usuario';
    final bio = user?.bio?.trim();
    final unread = context.watch<SocialSummaryProvider>().unreadCount;
    const avatarSize = 112.0;
    const bannerHeight = 248.0;

    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bannerHeight,
                child: _ProfileBanner(imageUrl: user?.coverUrl),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 12, 0),
                    child: Row(
                      children: [
                        _CircleIconButton(
                          icon: Icons.arrow_back,
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                              return;
                            }
                            context.go('/feed');
                          },
                        ),
                        const Spacer(),
                        if (_isOwner) ...[
                          _CircleIconButton(
                            icon: Icons.notifications_outlined,
                            onTap: () => context.push('/notifications'),
                            showDot: unread > 0,
                          ),
                          const SizedBox(width: 8),
                          _CircleIconButton(
                            icon: Icons.settings_outlined,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_isOwner)
                Positioned(
                  right: 14,
                  bottom: avatarSize * 0.42,
                  child: Material(
                    color: const Color(0xCC111111),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _changingCover ? null : _changeCover,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: _changingCover
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: avatarSize,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _isOwner && !_publishingStory ? _addStoryFromAvatar : null,
                        child: SizedBox(
                          width: avatarSize,
                          height: avatarSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _hasActiveStory ? KairoColors.successText : Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: KairoAvatar(imageUrl: user?.image, name: name, size: avatarSize - 12),
                                ),
                              ),
                              if (_publishingStory)
                                const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary400),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: KairoColors.darkText, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: KairoColors.primary500,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                handle,
                style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (bio != null && bio.isNotEmpty)
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KairoColors.darkText, fontSize: 14, height: 1.35),
                )
              else if (_isOwner)
                const Text(
                  'Agrega una descripción',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14, height: 1.35),
                ),
            ],
          ),
        ),
      ],
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
    setState(() {
      _posts.removeWhere((p) => p.id == postId);
      _savedPosts.removeWhere((p) => p.id == postId);
    });
  }

  void _openProfilePost(Post post) {
    final posts = List<Post>.from(_displayPosts);
    if (posts.isEmpty) return;
    if (!posts.any((p) => p.id == post.id)) {
      posts.insert(0, post);
    }
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Cerrar',
      pageBuilder: (ctx, _, __) {
        return ProfileGalleryViewer(
          posts: posts,
          initialPostId: post.id,
          onEditContent: _updatePostContent,
          onDeleteText: (id) => _updatePostContent(id, ''),
          onDeletePost: _deletePost,
        );
      },
    );
  }

  Future<void> _shareProfile() async {
    final user = _profile?.user;
    if (user == null) return;
    await showKairoShareSheet(
      context,
      title: 'Compartir perfil',
      shareText: buildProfileShareText(user),
      shareLink: buildProfileShareLink(user.id),
      emailSubject: 'Perfil de ${user.displayName} en KAIRO',
      postPreview: user.handle.isNotEmpty ? user.handle : user.displayName,
    );
  }

  Future<void> _copyText(String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _showProfileMore() async {
    final user = _profile?.user;
    if (user == null) return;
    final handle = user.username?.trim();
    final hasHandle = handle != null && handle.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: KairoColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        void closeThen(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        Widget item({
          required IconData icon,
          required String title,
          String? subtitle,
          Color? color,
          required VoidCallback onTap,
        }) {
          return ListTile(
            leading: Icon(icon, color: color ?? Colors.white),
            title: Text(title, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
            onTap: onTap,
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: KairoColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Más opciones',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                item(
                  icon: Icons.link,
                  title: 'Copiar enlace del perfil',
                  onTap: () => closeThen(() => _copyText(buildProfileShareLink(user.id), 'Enlace copiado')),
                ),
                if (hasHandle)
                  item(
                    icon: Icons.alternate_email,
                    title: 'Copiar usuario',
                    subtitle: '@$handle',
                    onTap: () => closeThen(() => _copyText('@$handle', 'Usuario copiado')),
                  ),
                if (!_isOwner)
                  item(
                    icon: Icons.block,
                    title: 'Bloquear',
                    color: KairoColors.errorText,
                    onTap: () => closeThen(() => _blockUser(user)),
                  ),
                if (_isOwner) ...[
                  item(
                    icon: Icons.people_outline,
                    title: 'Personas',
                    onTap: () => closeThen(() => context.push('/personas')),
                  ),
                  item(
                    icon: Icons.settings_outlined,
                    title: 'Ajustes',
                    onTap: () => closeThen(() => context.push('/settings')),
                  ),
                  item(
                    icon: Icons.logout,
                    title: 'Cerrar sesión',
                    color: KairoColors.errorText,
                    onTap: () => closeThen(() async {
                      await AuthService().signOut();
                      if (mounted) context.go('/auth/signin');
                    }),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _blockUser(KairoUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KairoColors.darkCard,
        title: Text('¿Bloquear a ${user.displayName}?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Dejará de ser tu amigo y quedará en Ajustes → Personas. Desde ahí puedes desbloquearlo o quitarlo de amigos.',
          style: TextStyle(color: KairoColors.darkTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bloquear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _usersRepo.blockUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.displayName} fue bloqueado')));
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo bloquear: $e')));
    }
  }

  Future<void> _editProfile() async {
    if (!_isOwner) return;
    await context.push('/profile/edit');
    if (mounted) await _load();
  }


  List<Post> get _displayPosts {
    switch (_tab) {
      case 'lista':
        return _posts.where((p) => p.isTextOnly).toList();
      case 'guardados':
        return _savedPosts;
      default:
        return _posts.where((p) => p.hasMedia).toList();
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
        ? ['publicaciones', 'lista', 'guardados']
        : ['publicaciones', 'lista'];

    return MainScaffold(
      child: RefreshIndicator(
        color: KairoColors.primary500,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _profileHero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Column(
                      children: [
                        _StatsRow(
                          items: _isOwner
                              ? [
                                  ('${_posts.length}', 'Publicaciones'),
                                  ('${_profile?.agregados ?? 0}', 'Agregados'),
                                  ('${_savedPosts.length}', 'Guardados'),
                                ]
                              : [
                                  ('${_posts.length}', 'Publicaciones'),
                                  ('${_profile?.agregados ?? 0}', 'Agregados'),
                                  ('${_profile?.teAgregaron ?? 0}', 'Te agregaron'),
                                ],
                        ),
                        if (_isOwner) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextButton.icon(
                                    onPressed: _editProfile,
                                    style: TextButton.styleFrom(
                                      backgroundColor: KairoColors.darkCard,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SquareAction(
                                icon: Icons.share,
                                onTap: _shareProfile,
                              ),
                              const SizedBox(width: 8),
                              _SquareAction(
                                icon: Icons.more_horiz,
                                onTap: _showProfileMore,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          FeelingsSelector(
                            currentMood: user?.mood,
                            moodUpdatedAt: user?.moodUpdatedAt,
                            onChanged: (mood) {
                              final current = _profile;
                              if (current == null) return;
                              setState(() {
                                _profile = current.copyWith(
                                  user: current.user.copyWith(
                                    mood: mood,
                                    moodUpdatedAt: DateTime.now(),
                                  ),
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 22),
                          MomentsStrip(
                            userId: _viewedUserId ?? AuthService().currentUser?.id ?? 'local',
                            isOwner: true,
                            author: user ??
                                KairoUser(
                                  id: _viewedUserId ?? AuthService().currentUser?.id ?? 'local',
                                  email: AuthService().currentUser?.email ?? '',
                                ),
                          ),
                        ],
                        if (!_isOwner && _profile != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _followLoading ? null : _toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _profile!.viewerHasAdded ? KairoColors.darkHover : KairoColors.primary500,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(_profile!.viewerHasAdded ? 'Agregado' : 'Agregar'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SquareAction(
                                icon: Icons.share,
                                onTap: _shareProfile,
                              ),
                              const SizedBox(width: 8),
                              _SquareAction(
                                icon: Icons.more_horiz,
                                onTap: _showProfileMore,
                              ),
                            ],
                          ),
                          if (user != null && user.hasActiveMood) ...[
                            const SizedBox(height: 22),
                            FeelingsSelector(
                              currentMood: user.mood,
                              moodUpdatedAt: user.moodUpdatedAt,
                              isOwner: false,
                            ),
                          ],
                          if (user != null && _viewedUserId != null) ...[
                            const SizedBox(height: 22),
                            MomentsStrip(
                              userId: _viewedUserId!,
                              isOwner: false,
                              author: user,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: tabs.map((t) {
                    final active = _tab == t;
                    final isSaved = t == 'guardados';
                    final isList = t == 'lista';
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _tab = t);
                          if (t == 'guardados') _loadSaved();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: const BorderSide(color: KairoColors.darkBorder),
                              bottom: BorderSide(
                                color: active ? Colors.white : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSaved
                                    ? Icons.bookmark_border
                                    : isList
                                        ? Icons.view_list_outlined
                                        : Icons.grid_view_rounded,
                                size: 16,
                                color: active ? Colors.white : KairoColors.darkTextSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isSaved ? 'Guardados' : isList ? 'Lista' : 'Publicaciones',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active ? Colors.white : KairoColors.darkTextSecondary,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (isSaved && _savedPosts.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: KairoColors.purple500,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${_savedPosts.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SliverPadding(
              padding: _tab == 'lista'
                  ? const EdgeInsets.only(top: 8, bottom: 100)
                  : const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: SliverToBoxAdapter(
                child: _tab == 'lista'
                    ? ProfileTextList(
                        posts: _displayPosts,
                        onEditContent: _updatePostContent,
                        onDeleteText: (id) => _updatePostContent(id, ''),
                        onDeletePost: _deletePost,
                      )
                    : ProfilePostsGrid(
                        posts: _displayPosts,
                        moodBadge: user?.hasActiveMood == true ? user!.mood : null,
                        onOpen: _openProfilePost,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: KairoColors.darkCard,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: KairoColors.darkCard.withValues(alpha: 0.88),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: KairoColors.primary500,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _CoverWaveClipper extends CustomClipper<Path> {
  const _CoverWaveClipper();

  @override
  Path getClip(Size size) {
    return _coverWavePath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

Path _coverWavePath(Size size) {
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(0, 0)
    ..lineTo(w, 0)
    ..lineTo(w, h * 0.74)
    ..cubicTo(w * 0.90, h * 0.72, w * 0.78, h * 0.80, w * 0.62, h * 0.90)
    ..cubicTo(w * 0.52, h * 0.95, w * 0.44, h * 0.94, w * 0.34, h * 0.89)
    ..cubicTo(w * 0.20, h * 0.85, w * 0.10, h * 0.88, 0, h * 0.90)
    ..close();
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _CoverWaveClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: KairoColors.darkCard),
          if (imageUrl != null)
            CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          else
            const CustomPaint(painter: _BannerPainter()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x220A0A0A),
                  Color(0x000A0A0A),
                  Color(0x660A0A0A),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  const _BannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [KairoColors.primary700, KairoColors.darkCard, KairoColors.purple600],
      ).createShader(rect);
    canvas.drawRect(rect, fill);

    final wave = Paint()
      ..color = KairoColors.primary400.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(size.width * 0.25, size.height * 0.25, size.width * 0.45, size.height * 0.85, size.width * 0.7, size.height * 0.45)
      ..cubicTo(size.width * 0.85, size.height * 0.22, size.width * 0.95, size.height * 0.4, size.width, size.height * 0.3);
    canvas.drawPath(path, wave);

    final wave2 = Paint()
      ..color = KairoColors.purple500.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path2 = Path()
      ..moveTo(0, size.height * 0.72)
      ..cubicTo(size.width * 0.3, size.height * 0.95, size.width * 0.55, size.height * 0.4, size.width, size.height * 0.62);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(width: 1, height: 28, color: KairoColors.darkBorder),
          Expanded(
            child: Column(
              children: [
                Text(
                  items[i].$1,
                  style: const TextStyle(color: KairoColors.darkText, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  items[i].$2,
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
