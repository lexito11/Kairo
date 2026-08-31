import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../users/services/users_repository.dart';
import '../live_catalog.dart';

const _teal = Color(0xFF2DD4BF);

class GoLiveView extends StatefulWidget {
  const GoLiveView({super.key});

  @override
  State<GoLiveView> createState() => _GoLiveViewState();
}

class _GoLiveViewState extends State<GoLiveView> {
  final _title = TextEditingController();
  bool _cameraOn = false;
  bool _micOn = true;
  bool _starting = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _retryCamera() async {
    setState(() => _cameraOn = true);
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final me = await UsersRepository().getCurrentUser();
      if (!mounted) return;
      if (me == null) {
        context.push('/auth/signin');
        return;
      }
      final stream = LiveCatalog.instance.startLive(
        host: me,
        title: _title.text,
      );
      if (!mounted) return;
      context.pushReplacement('/live/${stream.id}');
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
                      'Configura antes de ir en vivo',
                      style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFF1A1A1A),
                    child: _cameraOn
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam, color: Colors.white54, size: 40),
                                SizedBox(height: 8),
                                Text('Cámara lista', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 42),
                              const SizedBox(height: 10),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Permite el acceso a la cámara para previsualizar.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _retryCamera,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _teal,
                                  side: const BorderSide(color: _teal),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Horizontal 16:9',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        _RoundIcon(
                          icon: Icons.cameraswitch_outlined,
                          onTap: () {
                            if (!_cameraOn) {
                              setState(() => _cameraOn = true);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _RoundIcon(
                          icon: _micOn ? Icons.mic : Icons.mic_off,
                          onTap: () => setState(() => _micOn = !_micOn),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _teal),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KairoColors.darkCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _StatusDot(active: _micOn, label: _micOn ? 'Micrófono activo' : 'Micrófono off'),
                const SizedBox(width: 16),
                _StatusDot(active: _cameraOn, label: _cameraOn ? 'Cámara activa' : 'Cámara off'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _starting ? null : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(_starting ? 'Conectando...' : 'Ir en vivo', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, required this.label});
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF22C55E) : KairoColors.darkTextSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
