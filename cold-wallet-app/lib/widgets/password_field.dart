import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({super.key, required this.controller, required this.hintText, this.onChanged, this.onSubmitted});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderButton, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscured,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: text.smallParagraph?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(hintText: widget.hintText),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _obscured = !_obscured),
            child: Icon(
              _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
