import 'package:flutter/material.dart';
import '../../../core/theme/kairo_colors.dart';

class KairoTextField extends StatefulWidget {
  const KairoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.keyboardType,
    this.enabled = true,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscureText;
  final bool showVisibilityToggle;
  final TextInputType? keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;

  @override
  State<KairoTextField> createState() => _KairoTextFieldState();
}

class _KairoTextFieldState extends State<KairoTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant KairoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showVisibilityToggle && oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: KairoColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          validator: widget.validator,
          style: const TextStyle(color: KairoColors.darkText),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: KairoColors.darkTextSecondary),
            filled: true,
            fillColor: KairoColors.darkBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: widget.showVisibilityToggle
                ? IconButton(
                    onPressed: widget.enabled
                        ? () => setState(() => _obscured = !_obscured)
                        : null,
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: KairoColors.darkTextSecondary,
                      size: 22,
                    ),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: KairoColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: KairoColors.primary500, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: KairoColors.darkBorder),
            ),
          ),
        ),
      ],
    );
  }
}
