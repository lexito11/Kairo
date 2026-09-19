import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/prefs_service.dart';
import '../../../core/theme/kairo_colors.dart';

class SearchRecentsScreen extends StatefulWidget {
  const SearchRecentsScreen({super.key});

  @override
  State<SearchRecentsScreen> createState() => _SearchRecentsScreenState();
}

class _SearchRecentsScreenState extends State<SearchRecentsScreen> {
  final _prefs = PrefsService();
  List<String> _recents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recents = await _prefs.getSearchRecents();
    if (!mounted) return;
    setState(() {
      _recents = recents;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    await _prefs.clearSearchRecents();
    if (mounted) setState(() => _recents = []);
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
        title: const Text('Búsquedas recientes', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_recents.isNotEmpty)
            TextButton(
              onPressed: _clearHistory,
              child: const Text(
                'Limpiar historial',
                style: TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : _recents.isEmpty
              ? const Center(
                  child: Text(
                    'No hay búsquedas recientes',
                    style: TextStyle(color: KairoColors.darkTextSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 24),
                  itemCount: _recents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: KairoColors.darkBorder),
                  itemBuilder: (context, index) {
                    final query = _recents[index];
                    return ListTile(
                      leading: const Icon(Icons.search_rounded, color: KairoColors.darkTextSecondary),
                      title: Text(query, style: const TextStyle(color: KairoColors.darkText, fontSize: 15)),
                      onTap: () => context.pop(query),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () async {
                          await _prefs.removeSearchRecent(query);
                          if (mounted) setState(() => _recents.removeAt(index));
                        },
                        icon: const Icon(Icons.close_rounded, color: KairoColors.darkTextSecondary, size: 18),
                      ),
                    );
                  },
                ),
    );
  }
}
