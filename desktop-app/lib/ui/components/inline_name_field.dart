import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A name typed over where it is shown, as Finder renames: Return, leaving
/// the field, or the field going away while it is typed in (another rename
/// starting, the sidebar hidden) keeps what was typed ([onKeep]), and Escape
/// puts the name back ([onCancel]) without keeping anything.
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
  ///
  /// It can be called once the field and what holds it are gone, so it does
  /// not read through a widget's `ref` or touch a widget's state that is not
  /// mounted.
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

  /// Whether the name is being typed: from the field taking the focus until
  /// what was typed is kept, or Escape puts the name back.
  bool _editing = false;

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
    // Going away while typed in: what was typed is kept, as leaving the field
    // keeps it. The focus node says nothing once disposed, and the tree is
    // locked while the field is taken down, so it is kept just after.
    if (_editing) {
      final keep = widget.onKeep;
      final entered = _controller.text;
      Future.microtask(() => keep(entered));
    }
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _editing = true;
      return;
    }
    if (!_editing) return;
    _editing = false;
    _keep();
  }

  Future<void> _keep() async {
    final shown = await widget.onKeep(_controller.text);
    if (mounted && shown != null) _controller.text = shown;
  }

  void _putBack() {
    _editing = false;
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
