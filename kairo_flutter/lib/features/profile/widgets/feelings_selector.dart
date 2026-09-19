import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  State<FeelingsSelector> createState() => _FeelingsSelectorState();
}

class _FeelingsSelectorState extends State<FeelingsSelector> {
  final _repo = UsersRepository();
  late final TextEditingController _controller;
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
    _controller = TextEditingController(text: _locked ? '' : (widget.currentMood ?? ''));
    _scheduleUnlock();
  }

  @override
  void didUpdateWidget(covariant FeelingsSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMood != widget.currentMood) {
      _selected = widget.currentMood;
      if (!_locked) {
        _controller.text = widget.currentMood ?? '';
      }
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
    _controller.dispose();
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

  Future<void> _save() async {
    if (!widget.isOwner || _saving || _locked) return;
    final value = _controller.text.trim();
    if (value.isEmpty) return;
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
      if (mounted) _controller.clear();
    } catch (_) {
      if (mounted) {
        setState(() {
          _selected = widget.currentMood;
          _updatedAt = widget.moodUpdatedAt;
        });
        _scheduleUnlock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar cómo te sientes')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _remainingLabel {
    final left = _remaining;
    if (left.inHours >= 1) {
      return 'Podrás cambiarlo en ${left.inHours} h';
    }
    final minutes = left.inMinutes.clamp(1, 59);
    return 'Podrás cambiarlo en $minutes min';
  }

  Widget _moodChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KairoColors.primary500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOwner && !_locked) return const SizedBox.shrink();

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
        if (!widget.isOwner)
          _moodChip(_selected!.trim())
        else if (_locked) ...[
          _moodChip(_selected!.trim()),
          const SizedBox(height: 8),
          Text(
            _remainingLabel,
            style: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 11),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: KairoUser.moodMaxLength,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(KairoUser.moodMaxLength),
                  ],
                  style: const TextStyle(color: KairoColors.darkText, fontSize: 14),
                  cursorColor: KairoColors.primary500,
                  decoration: InputDecoration(
                    hintText: 'Escribe cómo te sientes',
                    hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                    counterText: '',
                    filled: true,
                    fillColor: KairoColors.darkCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KairoColors.primary500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
