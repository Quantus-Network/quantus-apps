import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return QuantusTextField(
      controller: widget.controller,
      hint: widget.hintText,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction:
          widget.textInputAction ?? (widget.onSubmitted != null ? TextInputAction.done : TextInputAction.next),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      trailing: GestureDetector(
        onTap: () => setState(() => _obscured = !_obscured),
        behavior: HitTestBehavior.opaque,
        child: Icon(
          _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 22,
          color: colors.textMuted,
        ),
      ),
    );
  }
}
