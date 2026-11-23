import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A field's label in capitals, with the field's [actions] at the end of the
/// label's line.
class SendFieldLabel extends StatelessWidget {
  const SendFieldLabel({super.key, required this.label, this.actions = const []});

  final String label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ToolbarAction.height,
      child: Row(
        children: [
          Expanded(child: CapsText(label, style: context.sendCaps())),
          ToolbarActionRow(edge: ToolbarActionEdge.trailing, spacing: 0, children: actions),
        ],
      ),
    );
  }
}

/// A field of the Send form at desktop size: 36 high, dark inside. What is
/// wrong with what it holds, if anything, is said under it as [error]. One
/// that is not [enabled] shows what it holds at half strength, and neither
/// the mouse nor the keyboard can reach it.
class SendField extends StatelessWidget {
  const SendField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.style,
    this.enabled = true,
    this.error,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextStyle style;
  final bool enabled;
  final String? error;

  /// A unit shown at the field's end.
  final String? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const double height = 36;
  static const double _suffixWidth = 44;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final suffix = this.suffix;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: QuantusTextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        hint: hint,
        error: error,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: style,
        fillColor: colors.bgVoid,
        borderRadius: context.radiusV3.smBorder,
        trailingWidth: suffix == null ? null : _suffixWidth,
        trailing: suffix == null
            ? null
            // The field keeps 4 clear beyond it; with this the unit ends where
            // the text begins on the other side, 12 in.
            : Container(
                width: _suffixWidth,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: Text(suffix, style: context.sendMono(colors.textMuted)),
              ),
      ),
    );
  }
}

/// One address used before: the whole address over its checkphrase. A press
/// picks it. It has a soft backing under the cursor, stronger while
/// pressed, and a ring when it has the keyboard's focus.
class SendRecentRow extends StatefulWidget {
  const SendRecentRow({super.key, required this.address, required this.onPressed, this.showsCheckphrase = true});

  final String address;
  final VoidCallback onPressed;

  /// Whether the address has a checkphrase to show under it: one on another
  /// chain has none.
  final bool showsCheckphrase;

  @override
  State<SendRecentRow> createState() => _SendRecentRowState();
}

class _SendRecentRowState extends State<SendRecentRow> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.smBorder;
    final backing = _isPressed
        ? 0.1
        : _isHovered
        ? 0.06
        : 0.0;

    return Semantics(
      button: true,
      label: widget.address,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: _isFocused ? Border.all(color: colors.accentFlare.useOpacity(0.7), width: 2) : null,
            ),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: colors.textContent.useOpacity(backing), borderRadius: radius),
              child: widget.showsCheckphrase
                  ? DesktopAddressCheckphrase(address: widget.address)
                  : Text(widget.address, style: context.sendMono(colors.textWhite)),
            ),
          ),
        ),
      ),
    );
  }
}
