import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';
import '../services/bible_text_size_store.dart';

class BibleBackButton extends StatelessWidget {
  const BibleBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.canPop() ? context.pop() : context.go('/feed'),
      style: IconButton.styleFrom(backgroundColor: KairoColors.darkHover),
      icon: const Icon(Icons.arrow_back, color: Colors.white),
    );
  }
}

class BibleTextSizeControls extends StatelessWidget {
  const BibleTextSizeControls({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BibleTextSizeStore.instance,
      builder: (context, _) {
        final store = BibleTextSizeStore.instance;
        return Container(
          decoration: BoxDecoration(
            color: KairoColors.darkHover,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SizeBtn(
                label: 'A-',
                tooltip: 'Reducir texto',
                fontSize: 12,
                enabled: store.canDecrease,
                onTap: store.decrease,
              ),
              Container(width: 1, height: 18, color: KairoColors.darkBorder),
              _SizeBtn(
                label: 'A+',
                tooltip: 'Ampliar texto',
                fontSize: 16,
                enabled: store.canIncrease,
                onTap: store.increase,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SizeBtn extends StatelessWidget {
  const _SizeBtn({
    required this.label,
    required this.tooltip,
    required this.fontSize,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final double fontSize;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : KairoColors.darkTextSecondary,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class BibleChapterStepper extends StatefulWidget {
  const BibleChapterStepper({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onSubmitted,
    this.min = 1,
    this.enabled = true,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onSubmitted;
  final bool enabled;

  @override
  State<BibleChapterStepper> createState() => _BibleChapterStepperState();
}

class _BibleChapterStepperState extends State<BibleChapterStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  int get _max => widget.max < widget.min ? widget.min : widget.max;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(BibleChapterStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit({bool fromSubmit = false}) {
    if (!widget.enabled) {
      _controller.text = '${widget.value}';
      return;
    }
    final parsed = int.tryParse(_controller.text);
    final next = (parsed ?? widget.value).clamp(widget.min, _max);
    if (_controller.text != '$next') _controller.text = '$next';
    if (next != widget.value) widget.onChanged(next);
    if (fromSubmit) widget.onSubmitted?.call(next);
  }

  void _step(int delta) {
    if (!widget.enabled) return;
    final next = (widget.value + delta).clamp(widget.min, _max);
    _controller.text = '$next';
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final canDown = widget.enabled && widget.value > widget.min;
    final canUp = widget.enabled && widget.value < _max;
    return SizedBox(
      width: 148,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: KairoColors.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _ArrowBtn(
              icon: Icons.chevron_left,
              tooltip: 'Capítulo anterior',
              enabled: canDown,
              onTap: () => _step(-1),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                cursorColor: KairoColors.primary500,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commit(fromSubmit: true),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Cap.',
                  hintStyle: TextStyle(color: KairoColors.darkTextSecondary, fontSize: 13),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            _ArrowBtn(
              icon: Icons.chevron_right,
              tooltip: 'Capítulo siguiente',
              enabled: canUp,
              onTap: () => _step(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  const _ArrowBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 36,
          height: 48,
          child: Icon(
            icon,
            color: enabled ? Colors.white : KairoColors.darkTextSecondary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class BibleSearchField extends StatelessWidget {
  const BibleSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint = 'Buscar libros...',
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Container(
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: KairoColors.primary500,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: KairoColors.darkTextSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: KairoColors.darkTextSecondary),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
          filled: true,
          fillColor: Colors.transparent,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
      ),
    );
  }
}

class BibleSkeletonBox extends StatelessWidget {
  const BibleSkeletonBox({
    super.key,
    this.height = 64,
    this.borderRadius = 14,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: KairoColors.darkCard,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class BibleBooksSkeleton extends StatelessWidget {
  const BibleBooksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget column() {
      return Column(
        children: List.generate(
          8,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: BibleSkeletonBox(height: 44, borderRadius: 10),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column()),
        const SizedBox(width: 8),
        Expanded(child: column()),
      ],
    );
  }
}

class BibleVersesSkeleton extends StatelessWidget {
  const BibleVersesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: 12,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: BibleSkeletonBox(height: 48),
      ),
    );
  }
}
