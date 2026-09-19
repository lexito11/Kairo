import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/kairo_avatar.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../users/services/users_repository.dart';
import '../services/live_feed_controller.dart';
import '../services/live_repository.dart';
import '../widgets/live_widgets.dart';

class GoLiveView extends StatefulWidget {
  const GoLiveView({super.key});

  @override
  State<GoLiveView> createState() => _GoLiveViewState();
}

class _GoLiveViewState extends State<GoLiveView> {
  final _title = TextEditingController();
  final _repo = LiveRepository();
  bool _starting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final me = await UsersRepository().getCurrentUser();
      if (!mounted) return;
      if (me == null) {
        context.push('/auth/signin');
        return;
      }
      final stream = await _repo.startLive(
        title: _title.text,
        thumbnailUrl: me.image,
      );
      await LiveFeedController.instance.refresh();
      if (!mounted) return;
      context.pushReplacement('/live/${stream.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _repo.mapError(e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return MainScaffold(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, top + 4, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva Transmisión',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Abre una sala en vivo para la comunidad',
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: UsersRepository().getCurrentUser(),
            builder: (context, snap) {
              final me = snap.data;
              return AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: const Color(0xFF1A1A1A),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KairoAvatar(imageUrl: me?.image, name: me?.displayName ?? 'Tú', size: 64),
                        const SizedBox(height: 10),
                        const LiveBadge(showDot: true),
                        const SizedBox(height: 8),
                        Text(
                          me?.displayName ?? 'Tu sala',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chat y presencia en tiempo real',
                          style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Título de la transmisión',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Ej: Culto Dominical en Vivo 🙏',
              hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontStyle: FontStyle.italic),
              filled: true,
              fillColor: KairoColors.darkCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KairoColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KairoColors.darkBorder),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF2DD4BF)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_title.text.characters.length}/80',
              style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: KairoColors.errorText, height: 1.35)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _starting ? null : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: liveRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                _starting ? 'Abriendo sala...' : 'Ir en vivo',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
