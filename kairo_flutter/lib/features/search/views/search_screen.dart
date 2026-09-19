import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/chat_group.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/models/post.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../messages/services/groups_repository.dart';
import '../../posts/widgets/comments_sheet.dart';
import '../services/search_repository.dart';
import '../widgets/search_shared.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _categories = ['Todo', 'Personas', 'Publicaciones', 'Videos', 'Grupos'];

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _repo = SearchRepository();
  final _prefs = PrefsService();
  final _groups = GroupsRepository();

  String _selectedCategory = 'Todo';
  String _searchQuery = '';
  List<String> _recents = [];
  List<SearchTrend> _trends = [];
  List<KairoUser> _suggested = [];
  List<Post> _recentPosts = [];
  Set<String> _followingIds = {};
  final Set<String> _followLoading = {};
  CommunitySearchResults _results = CommunitySearchResults.empty;
  bool _homeLoading = true;
  bool _searching = false;
  Timer? _debounce;
  int _searchGen = 0;

  bool get _hasQuery => _searchQuery.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      _searchQuery = initial;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
    _loadHome();
    if (_hasQuery) _runSearch(_searchQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    try {
      final recents = await _prefs.getSearchRecents();
      final trends = await _repo.fetchTrends();
      final people = await _repo.fetchSuggestedPeople();
      final posts = await _repo.fetchRecentPosts(limit: 12);
      final following = await _repo.fetchFollowingIds();
      if (!mounted) return;
      setState(() {
        _recents = recents;
        _trends = trends;
        _suggested = people;
        _recentPosts = posts;
        _followingIds = following;
        _homeLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _homeLoading = false);
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _searchQuery = value);
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _searchGen++;
      setState(() {
        _results = CommunitySearchResults.empty;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String value, {bool persist = false}) async {
    final gen = ++_searchGen;
    setState(() => _searching = true);
    try {
      final results = await _repo.search(value);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _results = results;
        _followingIds = {..._followingIds, ...results.followingIds};
        _searching = false;
      });
      if (persist) await _remember(value);
    } catch (_) {
      if (mounted && gen == _searchGen) setState(() => _searching = false);
    }
  }

  Future<void> _remember(String value) async {
    await _prefs.addSearchRecent(value);
    final recents = await _prefs.getSearchRecents();
    if (mounted) setState(() => _recents = recents);
  }

  void _applyQuery(String value, {bool persist = true}) {
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _searchQuery = value);
    _searchFocus.requestFocus();
    _runSearch(value, persist: persist);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchGen++;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _results = CommunitySearchResults.empty;
      _searching = false;
    });
    _searchFocus.requestFocus();
  }

  Future<void> _submitSearch(String value) async {
    final q = value.trim();
    if (q.isEmpty) return;
    await _runSearch(q, persist: true);
  }

  Future<void> _openRecents() async {
    final query = await context.push<String>('/search/recents');
    if (query != null && query.trim().isNotEmpty && mounted) {
      _applyQuery(query);
    } else if (mounted) {
      _recents = await _prefs.getSearchRecents();
      setState(() {});
    }
  }

  Future<void> _openTrends() async {
    final tag = await context.push<String>('/search/trends');
    if (tag != null && tag.trim().isNotEmpty && mounted) {
      _applyQuery(tag);
    }
  }

  Future<void> _toggleFollow(KairoUser user) async {
    if (!await ensureSignedIn(context)) return;
    final following = _followingIds.contains(user.id);
    setState(() => _followLoading.add(user.id));
    try {
      await _repo.toggleFollow(user.id, following: following);
      if (!mounted) return;
      setState(() {
        if (following) {
          _followingIds.remove(user.id);
        } else {
          _followingIds.add(user.id);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
      );
    } finally {
      if (mounted) setState(() => _followLoading.remove(user.id));
    }
  }

  void _openProfile(KairoUser user) {
    context.push('/profile?userId=${user.id}');
  }

  void _openPost(Post post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: post.id),
    );
  }

  Future<void> _openGroup(ChatGroup group) async {
    if (!await ensureSignedIn(context)) return;
    try {
      if (!group.isMember && group.isPublic) {
        await _groups.joinPublicGroup(group.id);
      } else if (!group.isMember) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este grupo es privado')),
        );
        return;
      }
      if (!mounted) return;
      context.push('/chat/group/${group.id}?name=${Uri.encodeComponent(group.name)}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el grupo')),
      );
    }
  }

  void _showFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KairoColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Filtrar resultados',
                  style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              for (final label in _categories)
                ListTile(
                  title: Text(label, style: const TextStyle(color: KairoColors.darkText)),
                  trailing: label == _selectedCategory
                      ? const Icon(Icons.check_rounded, color: KairoColors.primary400)
                      : null,
                  onTap: () {
                    setState(() => _selectedCategory = label);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _HeroHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.list(
              children: [
                _SearchInput(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onQueryChanged,
                  onSubmitted: _submitSearch,
                  onClear: _hasQuery ? _clearQuery : null,
                  onFilter: _showFilters,
                ),
                const SizedBox(height: 16),
                _CategoryChips(
                  categories: _categories,
                  selected: _selectedCategory,
                  onSelected: (value) => setState(() => _selectedCategory = value),
                ),
                const SizedBox(height: 22),
                if (_hasQuery)
                  _searching && _results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(
                            child: CircularProgressIndicator(color: KairoColors.primary500),
                          ),
                        )
                      : _SearchResultsView(
                          results: _results,
                          selectedCategory: _selectedCategory,
                          followingIds: _followingIds,
                          followLoading: _followLoading,
                          onOpenProfile: _openProfile,
                          onToggleFollow: _toggleFollow,
                          onOpenPost: _openPost,
                          onOpenGroup: _openGroup,
                        )
                else if (_homeLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: CircularProgressIndicator(color: KairoColors.primary500)),
                  )
                else ...[
                  SearchSectionHeader(
                    icon: Icons.schedule_rounded,
                    title: 'Búsquedas recientes',
                    onSeeAll: _openRecents,
                  ),
                  const SizedBox(height: 8),
                  if (_recents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Aún no hay búsquedas recientes',
                        style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
                      ),
                    )
                  else
                    ..._recents.take(5).map(
                      (query) => _RecentSearchTile(
                        query: query,
                        onTap: () => _applyQuery(query),
                        onRemove: () async {
                          await _prefs.removeSearchRecent(query);
                          final next = await _prefs.getSearchRecents();
                          if (mounted) setState(() => _recents = next);
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  SearchSectionHeader(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Tendencias en la comunidad',
                    onSeeAll: _openTrends,
                  ),
                  const SizedBox(height: 12),
                  if (_trends.isEmpty)
                    const Text(
                      'Cuando haya más publicaciones, aquí verás las tendencias.',
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
                    )
                  else
                    _HashtagRow(
                      tags: _trends.take(5).map((t) => t.tag).toList(),
                      onTagTap: _applyQuery,
                    ),
                  const SizedBox(height: 22),
                  SearchSectionHeader(
                    title: 'Personas que podrías agregar',
                    onSeeAll: () => context.push('/search/people'),
                  ),
                  const SizedBox(height: 14),
                  if (_suggested.isEmpty)
                    const Text(
                      'No hay sugerencias por ahora',
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
                    )
                  else
                    _SuggestedPeopleRow(
                      people: _suggested,
                      followingIds: _followingIds,
                      followLoading: _followLoading,
                      onOpen: _openProfile,
                      onToggleFollow: _toggleFollow,
                    ),
                  const SizedBox(height: 22),
                  SearchSectionHeader(
                    title: 'Publicaciones recientes',
                    onSeeAll: () => context.push('/search/posts'),
                  ),
                  const SizedBox(height: 12),
                  if (_recentPosts.isEmpty)
                    const Text(
                      'Aún no hay publicaciones',
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
                    )
                  else
                    _RecentPostsRow(posts: _recentPosts, onOpen: _openPost),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  static const _imageUrl =
      'https://images.unsplash.com/photo-1438232992991-995b7058bbb3?auto=format&fit=crop&w=1400&q=80';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 188 + top,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: _imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF111111)),
            errorWidget: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B140C), Color(0xFF0A0A0A)],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0xCC0A0A0A),
                  KairoColors.darkBg,
                ],
                stops: [0, 0.35, 0.82, 1],
              ),
            ),
          ),
          Positioned(
            top: top + 4,
            left: 8,
            child: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/feed');
                }
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.28),
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.18),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Todo lo que buscas,\nen un solo lugar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilter,
    this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilter;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: KairoColors.darkText, fontSize: 15),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Buscar en la comunidad...',
        hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 15),
        filled: true,
        fillColor: KairoColors.darkCard,
        prefixIcon: const Icon(Icons.search_rounded, color: KairoColors.darkTextSecondary),
        suffixIcon: onClear != null
            ? IconButton(
                tooltip: 'Limpiar',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, color: KairoColors.darkTextSecondary),
              )
            : IconButton(
                tooltip: 'Filtros',
                onPressed: onFilter,
                icon: const Icon(Icons.tune_rounded, color: KairoColors.darkTextSecondary),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: KairoColors.primary500),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = categories[index];
          final isSelected = label == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(label),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : KairoColors.darkText,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            selectedColor: KairoColors.primary500,
            backgroundColor: Colors.transparent,
            side: BorderSide(
              color: isSelected ? KairoColors.primary500 : KairoColors.darkBorder,
            ),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.query,
    required this.onRemove,
    this.onTap,
  });

  final String query;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(vertical: -2),
      onTap: onTap,
      leading: const Icon(Icons.search_rounded, color: KairoColors.darkTextSecondary, size: 22),
      title: Text(
        query,
        style: const TextStyle(color: KairoColors.darkText, fontSize: 15),
      ),
      trailing: IconButton(
        tooltip: 'Eliminar',
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded, color: KairoColors.darkTextSecondary, size: 18),
      ),
    );
  }
}

class _HashtagRow extends StatelessWidget {
  const _HashtagRow({required this.tags, this.onTagTap});

  final List<String> tags;
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = tags[index];
          return GestureDetector(
            onTap: onTagTap == null ? null : () => onTagTap!(tag),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: KairoColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: KairoColors.darkBorder),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: KairoColors.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SuggestedPeopleRow extends StatelessWidget {
  const _SuggestedPeopleRow({
    required this.people,
    required this.followingIds,
    required this.followLoading,
    required this.onOpen,
    required this.onToggleFollow,
  });

  final List<KairoUser> people;
  final Set<String> followingIds;
  final Set<String> followLoading;
  final ValueChanged<KairoUser> onOpen;
  final ValueChanged<KairoUser> onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final person = people[index];
          final following = followingIds.contains(person.id);
          final loading = followLoading.contains(person.id);
          return SizedBox(
            width: 118,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => onOpen(person),
                  child: KairoAvatar(imageUrl: person.image, name: person.displayName, size: 68),
                ),
                const SizedBox(height: 8),
                Text(
                  person.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: KairoColors.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  searchPersonSubtitle(person),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: SearchFollowButton(
                    following: following,
                    loading: loading,
                    onPressed: () => onToggleFollow(person),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecentPostsRow extends StatelessWidget {
  const _RecentPostsRow({required this.posts, required this.onOpen});

  final List<Post> posts;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final post = posts[index];
          return SizedBox(
            width: 148,
            height: 132,
            child: SearchMediaThumb(
              post: post,
              caption: post.content,
              onTap: () => onOpen(post),
            ),
          );
        },
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  const _SearchResultsView({
    required this.results,
    required this.selectedCategory,
    required this.followingIds,
    required this.followLoading,
    required this.onOpenProfile,
    required this.onToggleFollow,
    required this.onOpenPost,
    required this.onOpenGroup,
  });

  final CommunitySearchResults results;
  final String selectedCategory;
  final Set<String> followingIds;
  final Set<String> followLoading;
  final ValueChanged<KairoUser> onOpenProfile;
  final ValueChanged<KairoUser> onToggleFollow;
  final ValueChanged<Post> onOpenPost;
  final ValueChanged<ChatGroup> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final category = selectedCategory;
    final showPeople = category == 'Todo' || category == 'Personas';
    final showPosts = category == 'Todo' || category == 'Publicaciones';
    final showVideos = category == 'Todo' || category == 'Videos';
    final showGroups = category == 'Todo' || category == 'Grupos';

    final people = showPeople ? results.people : const <KairoUser>[];
    final posts = showPosts ? results.posts : const <Post>[];
    final videos = showVideos ? results.videos : const <Post>[];
    final groups = showGroups ? results.groups : const <ChatGroup>[];

    if (people.isEmpty && posts.isEmpty && videos.isEmpty && groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(
          child: Text(
            'No hay resultados',
            style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 15),
          ),
        ),
      );
    }

    final peopleBlock = people.isEmpty
        ? const <Widget>[]
        : [
            const SearchSectionHeader(title: 'Personas'),
            const SizedBox(height: 8),
            ...people.map(
              (user) => SearchPersonRow(
                user: user,
                following: followingIds.contains(user.id),
                followLoading: followLoading.contains(user.id),
                onOpen: () => onOpenProfile(user),
                onToggleFollow: () => onToggleFollow(user),
              ),
            ),
            const SizedBox(height: 18),
          ];

    final postsBlock = posts.isEmpty
        ? const <Widget>[]
        : [
            const SearchSectionHeader(title: 'Publicaciones'),
            const SizedBox(height: 12),
            _ResultsMediaGrid(posts: posts, onOpen: onOpenPost),
            const SizedBox(height: 18),
          ];

    final videosBlock = videos.isEmpty
        ? const <Widget>[]
        : [
            const SearchSectionHeader(title: 'Videos'),
            const SizedBox(height: 12),
            _ResultsMediaGrid(posts: videos, onOpen: onOpenPost),
            const SizedBox(height: 18),
          ];

    final groupsBlock = groups.isEmpty
        ? const <Widget>[]
        : [
            const SearchSectionHeader(title: 'Grupos'),
            const SizedBox(height: 8),
            ...groups.map((g) => SearchGroupRow(group: g, onTap: () => onOpenGroup(g))),
          ];

    final mediaBlocks = [...postsBlock, ...videosBlock];
    final ordered = results.peopleFirst
        ? [...peopleBlock, ...mediaBlocks, ...groupsBlock]
        : [...mediaBlocks, ...peopleBlock, ...groupsBlock];

    if (category == 'Personas') return Column(children: peopleBlock);
    if (category == 'Publicaciones') return Column(children: postsBlock);
    if (category == 'Videos') return Column(children: videosBlock);
    if (category == 'Grupos') return Column(children: groupsBlock);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ordered);
  }
}

class _ResultsMediaGrid extends StatelessWidget {
  const _ResultsMediaGrid({required this.posts, required this.onOpen});

  final List<Post> posts;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        return SearchMediaThumb(
          post: post,
          caption: post.content,
          onTap: () => onOpen(post),
        );
      },
    );
  }
}
