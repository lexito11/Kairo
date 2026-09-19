import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../services/official_messages_repository.dart';

class KairoOfficialChatView extends StatefulWidget {
  const KairoOfficialChatView({super.key});

  @override
  State<KairoOfficialChatView> createState() => _KairoOfficialChatViewState();
}

class _KairoOfficialChatViewState extends State<KairoOfficialChatView> {
  final _repo = OfficialMessagesRepository();
  List<KairoOfficialMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.fetchMine();
    if (!mounted) return;
    setState(() {
      _messages = list;
      _loading = false;
    });
    await _repo.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      appBar: AppBar(
        backgroundColor: KairoColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KairoColors.darkText),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'KAIRO',
          style: TextStyle(color: KairoColors.darkText, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KairoColors.primary500))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Aún no hay avisos oficiales.',
                            style: TextStyle(color: KairoColors.darkTextSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final m = _messages[i];
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                constraints: const BoxConstraints(maxWidth: 520),
                                decoration: BoxDecoration(
                                  color: KairoColors.darkCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: KairoColors.darkBorder),
                                ),
                                child: Text(
                                  m.body,
                                  style: const TextStyle(
                                    color: KairoColors.darkText,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Text(
                    'Este es un canal oficial. No se puede responder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
