import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../services/search_repository.dart';
import '../widgets/search_shared.dart';

class SearchPeopleScreen extends StatefulWidget {
  const SearchPeopleScreen({super.key});

  @override
  State<SearchPeopleScreen> createState() => _SearchPeopleScreenState();
}

class _SearchPeopleScreenState extends State<SearchPeopleScreen> {
  final _repo = SearchRepository();
  List<KairoUser> _people = [];
  Set<String> _followingIds = {};
  final Set<String> _followLoading = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await _repo.fetchSuggestedPeople();
      final following = await _repo.fetchFollowingIds();
      if (!mounted) return;
      setState(() {
        _people = people;
        _followingIds = following;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Descubrir personas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : _people.isEmpty
              ? const Center(
                  child: Text(
                    'No hay personas para sugerir',
                    style: TextStyle(color: KairoColors.darkTextSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 24),
                  itemCount: _people.length,
                  separatorBuilder: (_, __) => const Divider(height: 20, color: KairoColors.darkBorder),
                  itemBuilder: (context, index) {
                    final person = _people[index];
                    return SearchPersonRow(
                      user: person,
                      following: _followingIds.contains(person.id),
                      followLoading: _followLoading.contains(person.id),
                      onOpen: () => context.push('/profile?userId=${person.id}'),
                      onToggleFollow: () => _toggleFollow(person),
                    );
                  },
                ),
    );
  }
}
