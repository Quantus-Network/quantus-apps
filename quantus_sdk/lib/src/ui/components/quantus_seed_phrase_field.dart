import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Masks the text as `x`s (multiline fields cannot use [TextField.obscureText]).
class ObscuringTextEditingController extends TextEditingController {
  ObscuringTextEditingController({super.text});

  bool _obscured = true;

  bool get obscured => _obscured;

  set obscured(bool value) {
    if (_obscured == value) return;
    _obscured = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (!_obscured) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return TextSpan(style: style, text: 'x' * text.length);
  }
}

/// Multiline recovery-phrase field, obscured by default with a visibility toggle.
class QuantusSeedPhraseField extends StatefulWidget {
  final ObscuringTextEditingController controller;
  final String? hint;
  final String? error;
  final ValueChanged<String>? onChanged;

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
        canRequestFocus: false,
      ),
    );
  }
}
