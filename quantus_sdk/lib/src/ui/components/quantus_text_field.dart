import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shared v3 text field: default, focus, and inline error chrome.
class QuantusTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final bool showClearButton;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final int? maxLines;
  final bool expands;
  final double? height;

  const QuantusTextField({
    super.key,
    required this.controller,
    this.hint,
    this.error,
    this.showClearButton = false,
    this.focusNode,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.onSubmitted,
    this.trailing,
    this.maxLines = 1,
    this.expands = false,
    this.height,
  }) : assert(!showClearButton || trailing == null, 'showClearButton and trailing are mutually exclusive'),
       assert(!expands || (maxLines == null && height != null), 'expands needs maxLines: null and an explicit height');

  @override
  State<QuantusTextField> createState() => _QuantusTextFieldState();
}

class _QuantusTextFieldState extends State<QuantusTextField> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  bool get _hasError => widget.error != null;

  bool get _isMultiline => widget.expands || widget.maxLines != 1;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(QuantusTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_rebuild);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _ownsFocusNode = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// Keep the editable area clear of the trailing widget, whatever its size.
  double _trailingReserve(Widget extra) => 4 + (extra is QuantusIconButton ? extra.buttonSize : 36);

  Color _borderColor(AppColorsV3 colors) {
    if (_hasError) return colors.semanticEmber.useOpacity(0.55);
    if (_focusNode.hasFocus) return colors.accentFlare;
    return colors.borderEmphasis;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final textStyle = context.themeTextV3.dataAddressLarge.copyWith(color: colors.textContent);
    final hintStyle = context.themeTextV3.dataAddressLarge.copyWith(color: colors.textMuted);
    final showClear = widget.showClearButton && widget.controller.text.isNotEmpty;
    final extra = showClear ? _QuantusTextFieldClearButton(onTap: widget.controller.clear) : widget.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: widget.height,
              constraints: widget.height == null ? const BoxConstraints(minHeight: 48) : null,
              padding: EdgeInsets.only(
                left: 14,
                right: extra == null ? 14 : _trailingReserve(extra),
                top: 14,
                bottom: 14,
              ),
              decoration: BoxDecoration(
                color: colors.bgSurface,
                borderRadius: context.radiusV3.mdBorder,
                border: Border.all(color: _borderColor(colors), width: 1),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                enableSuggestions: widget.enableSuggestions,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                autocorrect: widget.autocorrect,
                maxLines: widget.maxLines,
                expands: widget.expands,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: colors.accentFlare,
                style: textStyle,
                decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: hintStyle),
              ),
            ),
            if (extra != null)
              _isMultiline
                  ? Positioned(right: 4, top: 6, child: extra)
                  : Positioned(right: 4, top: 0, bottom: 0, child: Center(child: extra)),
          ],
        ),

        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(widget.error!, style: context.themeTextV3.caption.copyWith(color: colors.semanticEmber)),
        ],
      ],
    );
  }
}

class _QuantusTextFieldClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _QuantusTextFieldClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    const size = 20.0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.textMuted,
            border: Border.all(color: colors.borderHairline, width: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.close, size: 12, color: colors.textVoid),
        ),
      ),
    );
  }
}
