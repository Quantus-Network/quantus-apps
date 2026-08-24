import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final String? error;

  const PasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.error,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return QuantusTextField(
      controller: widget.controller,
      hint: widget.hintText,
      enabled: widget.enabled,
      error: widget.error,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction:
          widget.textInputAction ?? (widget.onSubmitted != null ? TextInputAction.done : TextInputAction.next),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      trailing: QuantusIconButton.ghost(
        icon: _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        onTap: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}
