import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/bible_book.dart';
import '../services/bible_saved_store.dart';
import '../widgets/bible_chrome.dart';

class BibleSavedView extends StatefulWidget {
  const BibleSavedView({super.key});

  @override
  State<BibleSavedView> createState() => _BibleSavedViewState();
}

class _BibleSavedViewState extends State<BibleSavedView> {
  List<BibleCitation> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await BibleSavedStore.instance.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _openImage(BibleCitation citation) {
    context.push(
      '/bible/image?text=${Uri.encodeComponent(citation.text)}&ref=${Uri.encodeComponent(citation.formatted)}',
    );
  }

  Future<void> _remove(BibleCitation citation) async {
    await BibleSavedStore.instance.remove(citation.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return MainScaffold(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 4, 16, 8),
            child: const Row(
              children: [
                BibleBackButton(),
                SizedBox(width: 8),
                Icon(Icons.bookmark_rounded, color: KairoColors.primary400, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guardados', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Versículos para compartir', style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: KairoColors.primary500));
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Aún no tienes versículos guardados.\nEn la lectura, toca un versículo y elige Guardar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KairoColors.darkTextSecondary, height: 1.45),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = _items[i];
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: KairoColors.darkCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.formatted,
                      style: const TextStyle(color: KairoColors.primary400, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.text,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, height: 1.4, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Crear imagen',
                onPressed: () => _openImage(item),
                icon: const Icon(Icons.photo_outlined, color: KairoColors.primary400),
              ),
              IconButton(
                tooltip: 'Quitar',
                onPressed: () => _remove(item),
                icon: const Icon(Icons.bookmark_remove_outlined, color: KairoColors.darkTextSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}
