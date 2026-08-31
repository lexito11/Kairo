import 'package:flutter/material.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../users/services/users_repository.dart';

class FeelingsSelector extends StatefulWidget {
  const FeelingsSelector({super.key, this.currentMood, this.onChanged});

  final String? currentMood;
  final ValueChanged<String>? onChanged;

  static const moods = [
    ('🙏', 'Agradecido'),
    ('😊', 'Feliz'),
    ('💪', 'Motivado'),
    ('🕊️', 'En paz'),
    ('📖', 'Estudiando la Biblia'),
    ('❤️', 'Bendecido'),
  ];

  @override
  State<FeelingsSelector> createState() => _FeelingsSelectorState();
}

class _FeelingsSelectorState extends State<FeelingsSelector> {
  final _repo = UsersRepository();
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMood;
  }

  @override
  void didUpdateWidget(covariant FeelingsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMood != widget.currentMood) {
      _selected = widget.currentMood;
    }
  }

  Future<void> _pick(String emoji, String label) async {
    final value = '$emoji $label';
    setState(() { _selected = value; _saving = true; });
    try {
      await _repo.updateMood(value);
      widget.onChanged?.call(value);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '¿CÓMO TE SIENTES HOY?',
              style: TextStyle(
                color: KairoColors.darkTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            if (_saving) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary500)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: FeelingsSelector.moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final m = FeelingsSelector.moods[i];
              final value = '${m.$1} ${m.$2}';
              final active = _selected == value;
              return GestureDetector(
                onTap: () => _pick(m.$1, m.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? KairoColors.purple500.withValues(alpha: 0.18) : KairoColors.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? KairoColors.purple500 : KairoColors.darkBorder),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: KairoColors.purple500.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '${m.$1} ${m.$2}',
                    style: TextStyle(
                      color: active ? Colors.white : KairoColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
