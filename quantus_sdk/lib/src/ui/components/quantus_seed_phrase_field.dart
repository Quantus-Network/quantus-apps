import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Multiline recovery-phrase field: obscured by default, with a visibility toggle.
///
/// Callers own the [controller] so import logic can read the phrase. When
/// [scrollToOnFocus] is set, focusing the field scrolls that widget into view
/// after the keyboard animation.
class QuantusSeedPhraseField extends StatefulWidget {
  final ObscuringTextEditingController controller;
  final String? hint;
  final String? error;
  final ValueChanged<String>? onChanged;

  /// Widget to scroll into view when the field gains focus (typically the import button).
  final GlobalKey? scrollToOnFocus;

  const QuantusSeedPhraseField({
    super.key,
    required this.controller,
    this.hint,
    this.error,
    this.onChanged,
    this.scrollToOnFocus,
  });

  @override
  State<QuantusSeedPhraseField> createState() => _QuantusSeedPhraseFieldState();
}

class _QuantusSeedPhraseFieldState extends State<QuantusSeedPhraseField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_revealOnFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_revealOnFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _revealOnFocus() {
    if (!_focusNode.hasFocus || widget.scrollToOnFocus == null) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final ctx = widget.scrollToOnFocus?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return QuantusTextField(
      controller: widget.controller,
      focusNode: _focusNode,
      hint: widget.hint,
      error: widget.error,
      height: 202,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      trailing: QuantusIconButton.ghost(
        icon: widget.controller.obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        onTap: () => setState(() => widget.controller.obscured = !widget.controller.obscured),
      ),
    );
  }
}
