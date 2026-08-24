import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Single-line password field with a visibility toggle.
///
/// Starts obscured. Callers own the [controller] and pass already-resolved [hint]
/// and [error] strings. Defaults [textInputAction] to [TextInputAction.done]
/// when [onSubmitted] is set, otherwise [TextInputAction.next].
class QuantusPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final String? error;

  const QuantusPasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.error,
    this.enabled = true,
  });

  @override
  State<QuantusPasswordField> createState() => _QuantusPasswordFieldState();
}

class _QuantusPasswordFieldState extends State<QuantusPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return QuantusTextField(
      controller: widget.controller,
      hint: widget.hint,
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
