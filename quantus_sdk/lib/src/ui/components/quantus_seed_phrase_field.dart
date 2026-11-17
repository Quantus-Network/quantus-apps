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

  /// How tall the field is.
  final double height;

  /// A row drawn inside the field under the phrase. With one, the visibility
  /// toggle sits at the end of that row instead of at the top right.
  final Widget? footer;

  const QuantusSeedPhraseField({
    super.key,
    required this.controller,
    this.hint,
    this.error,
    this.onChanged,
    this.scrollToOnFocus,
    this.height = 202,
    this.footer,
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
    final footer = widget.footer;
    final toggle = QuantusIconButton.ghost(
      icon: widget.controller.obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      size: footer == null ? IconButtonSize.medium : IconButtonSize.small,
      onTap: () => setState(() => widget.controller.obscured = !widget.controller.obscured),
      canRequestFocus: false,
    );

    return QuantusTextField(
      controller: widget.controller,
      focusNode: _focusNode,
      hint: widget.hint,
      error: widget.error,
      height: widget.height,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      trailing: footer == null ? toggle : null,
      footer: footer == null
          ? null
          : Row(
              children: [
                Expanded(child: footer),
                const SizedBox(width: 8),
                toggle,
              ],
            ),
    );
  }
}
