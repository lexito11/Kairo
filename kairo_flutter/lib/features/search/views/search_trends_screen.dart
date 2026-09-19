import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../services/search_repository.dart';

class SearchTrendsScreen extends StatefulWidget {
  const SearchTrendsScreen({super.key});

  @override
  State<SearchTrendsScreen> createState() => _SearchTrendsScreenState();
}

class _SearchTrendsScreenState extends State<SearchTrendsScreen> {
  final _repo = SearchRepository();
  List<SearchTrend> _trends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trends = await _repo.fetchTrends(limit: 20);
      if (!mounted) return;
      setState(() {
        _trends = trends;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
        title: const Text('Explorar tendencias', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : _trends.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no hay tendencias en la comunidad',
                    style: TextStyle(color: KairoColors.darkTextSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: _trends.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: KairoColors.darkBorder),
                  itemBuilder: (context, index) {
                    final trend = _trends[index];
                    return ListTile(
                      onTap: () => context.pop(trend.tag),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KairoColors.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KairoColors.darkBorder),
                        ),
                        child: const Icon(Icons.tag_rounded, color: KairoColors.primary400, size: 22),
                      ),
                      title: Text(
                        '${trend.tag} - ${trend.postsLabel}',
                        style: const TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    );
                  },
                ),
    );
  }
}
