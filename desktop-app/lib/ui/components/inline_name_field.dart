import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A name typed over where it is shown, as Finder renames: Return or leaving
/// the field keeps what was typed ([onKeep]), and Escape puts the name back
/// ([onCancel]) without keeping anything.
class InlineNameField extends StatefulWidget {
  const InlineNameField({
    super.key,
    required this.name,
    required this.onKeep,
    this.onCancel,
    this.autofocus = false,
    this.height = 30,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.textStyle,
  });

  /// The name as it is now. A change made elsewhere shows while the field is
  /// not being typed in.
  final String name;

  /// Keeps what was typed. Answers what the field shows after, or null to
  /// leave what was typed, as when keeping it failed.
  final Future<String?> Function(String entered) onKeep;

  final VoidCallback? onCancel;

  /// Takes the focus on showing, with the name selected to be typed over.
  final bool autofocus;

  final double height;
  final EdgeInsets padding;

  /// The body style in full strength unless given.
  final TextStyle? textStyle;

  @override
  State<InlineNameField> createState() => _InlineNameFieldState();
}

class _InlineNameFieldState extends State<InlineNameField> {
  late final _controller = TextEditingController(text: widget.name);
  final _focus = FocusNode();

  /// Set by Escape: the focus it gives up does not keep anything.
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focus.requestFocus();
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      });
    }
  }

  @override
  void didUpdateWidget(InlineNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.name != oldWidget.name) _controller.text = widget.name;
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    if (_cancelled) {
      _cancelled = false;
      return;
    }
    _keep();
  }

  Future<void> _keep() async {
    final shown = await widget.onKeep(_controller.text);
    if (mounted && shown != null) _controller.text = shown;
  }

  void _putBack() {
    _cancelled = true;
    _controller.text = widget.name;
    _focus.unfocus();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Actions(
      actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => _putBack())},
      child: QuantusTextField(
        controller: _controller,
        focusNode: _focus,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focus.unfocus(),
        height: widget.height,
        padding: widget.padding,
        textStyle: widget.textStyle ?? context.themeTextV3.body.copyWith(color: colors.textContent),
        fillColor: colors.bgVoid,
        borderRadius: context.radiusV3.smBorder,
        autocorrect: false,
        enableSuggestions: false,
      ),
    );
  }
}
