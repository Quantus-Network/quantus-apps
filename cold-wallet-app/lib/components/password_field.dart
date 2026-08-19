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
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final focused = _focusNode.hasFocus;

    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? colors.accentOrange : colors.borderButton, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              obscureText: _obscured,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction:
                  widget.textInputAction ?? (widget.onSubmitted != null ? TextInputAction.done : TextInputAction.next),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: text.smallParagraph?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(hintText: widget.hintText),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _obscured = !_obscured),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 22,
                color: focused ? colors.textSecondary : colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
