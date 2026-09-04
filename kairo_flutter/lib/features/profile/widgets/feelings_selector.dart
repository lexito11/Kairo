import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/models/kairo_user.dart';
import '../../../core/theme/kairo_colors.dart';
import '../../users/services/users_repository.dart';

class FeelingsSelector extends StatefulWidget {
  const FeelingsSelector({
    super.key,
    this.currentMood,
    this.moodUpdatedAt,
    this.isOwner = true,
    this.onChanged,
  });

  final String? currentMood;
  final DateTime? moodUpdatedAt;
  final bool isOwner;
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
  DateTime? _updatedAt;
  bool _saving = false;
  Timer? _unlockTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMood;
    _updatedAt = widget.moodUpdatedAt;
    _scheduleUnlock();
  }

  @override
  void didUpdateWidget(covariant FeelingsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMood != widget.currentMood) {
      _selected = widget.currentMood;
    }
    if (oldWidget.moodUpdatedAt != widget.moodUpdatedAt) {
      _updatedAt = widget.moodUpdatedAt;
      _scheduleUnlock();
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  bool get _locked {
    final selected = _selected?.trim();
    if (selected == null || selected.isEmpty || _updatedAt == null) return false;
    return DateTime.now().toUtc().difference(_updatedAt!.toUtc()) < KairoUser.moodLockDuration;
  }

  Duration get _remaining {
    if (_updatedAt == null) return Duration.zero;
    final unlocksAt = _updatedAt!.toUtc().add(KairoUser.moodLockDuration);
    final left = unlocksAt.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  void _scheduleUnlock() {
    _unlockTimer?.cancel();
    _tickTimer?.cancel();
    if (!_locked) return;
    final left = _remaining;
    if (left == Duration.zero) return;
    _unlockTimer = Timer(left, () {
      if (mounted) setState(() {});
    });
    _tickTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_locked) _tickTimer?.cancel();
    });
  }

  Future<void> _pick(String emoji, String label) async {
    if (!widget.isOwner || _saving || _locked) return;
    final value = '$emoji $label';
    final now = DateTime.now();
    setState(() {
      _selected = value;
      _updatedAt = now;
      _saving = true;
    });
    _scheduleUnlock();
    try {
      await _repo.updateMood(value);
      widget.onChanged?.call(value);
    } catch (_) {
      if (mounted) {
        setState(() {
          _selected = widget.currentMood;
          _updatedAt = widget.moodUpdatedAt;
        });
        _scheduleUnlock();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<(String, String)> get _visibleMoods {
    if (!_locked) return FeelingsSelector.moods;
    return FeelingsSelector.moods
        .where((m) => '${m.$1} ${m.$2}' == _selected)
        .toList();
  }

  String get _remainingLabel {
    final left = _remaining;
    if (left.inHours >= 1) {
      return 'Podrás cambiarlo en ${left.inHours} h';
    }
    final minutes = left.inMinutes.clamp(1, 59);
    return 'Podrás cambiarlo en $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOwner && !_locked) return const SizedBox.shrink();

    final moods = _visibleMoods;
    final showSelectedOnly = _locked && moods.isEmpty && (_selected?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.isOwner ? '¿CÓMO TE SIENTES HOY?' : 'HOY SE SIENTE',
              style: const TextStyle(
                color: KairoColors.darkTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            if (_saving) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: KairoColors.primary500),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: showSelectedOnly ? 1 : moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final label = showSelectedOnly ? _selected! : '${moods[i].$1} ${moods[i].$2}';
              final active = _selected == label || showSelectedOnly;
              return GestureDetector(
                onTap: widget.isOwner && !_locked && !showSelectedOnly
                    ? () => _pick(moods[i].$1, moods[i].$2)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? KairoColors.primary500 : KairoColors.darkCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
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
        if (widget.isOwner && _locked) ...[
          const SizedBox(height: 8),
          Text(
            _remainingLabel,
            style: const TextStyle(
              color: KairoColors.darkTextSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
