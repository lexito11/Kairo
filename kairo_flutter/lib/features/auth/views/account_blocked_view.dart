import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/moderation/kairo_content_policy.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../moderation/services/official_messages_repository.dart';
import '../services/auth_service.dart';

class AccountBlockedView extends StatefulWidget {
  const AccountBlockedView({super.key});

  @override
  State<AccountBlockedView> createState() => _AccountBlockedViewState();
}

class _AccountBlockedViewState extends State<AccountBlockedView> {
  final _official = OfficialMessagesRepository();
  List<KairoOfficialMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _official.fetchMine();
    if (!mounted) return;
    setState(() {
      _messages = list;
      _loading = false;
    });
    await _official.markAllRead();
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (mounted) context.go('/auth/signin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KairoColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, color: KairoColors.errorText, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Cuenta bloqueada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KairoColors.darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                KairoAccountBlockedException.userMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KairoColors.darkTextSecondary,
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Mensajes oficiales de KAIRO',
                style: TextStyle(
                  color: KairoColors.darkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: KairoColors.primary500),
                      )
                    : _messages.isEmpty
                        ? const Text(
                            'Tu contenido fue eliminado porque incumplió las normas de KAIRO. Esta infracción ha sido registrada en tu cuenta. Has alcanzado 4 infracciones acumuladas y tu cuenta ha sido bloqueada automáticamente.',
                            style: TextStyle(color: KairoColors.darkTextSecondary, height: 1.4),
                          )
                        : ListView.separated(
                            itemCount: _messages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: KairoColors.darkCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: KairoColors.darkBorder),
                                ),
                                child: Text(
                                  m.body,
                                  style: const TextStyle(
                                    color: KairoColors.darkText,
                                    height: 1.4,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _signOut,
                style: FilledButton.styleFrom(
                  backgroundColor: KairoColors.darkHover,
                  foregroundColor: KairoColors.darkText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
