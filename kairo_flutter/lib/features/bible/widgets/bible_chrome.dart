import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kairo_colors.dart';

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

class BibleSearchField extends StatelessWidget {
  const BibleSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint = 'Buscar libros, versículos...',
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
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
