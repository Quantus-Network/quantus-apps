import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// An action in the window's header: an icon in the accent colour and a
/// label, with no button drawn around them.
///
/// It behaves as a borderless toolbar button does on macOS. A soft backing
/// appears under the cursor and grows stronger while the action is pressed;
/// the cursor stays an arrow, the pointing hand being for links; Tab reaches
/// it, a ring shows it has the keyboard's focus, and Space presses it. With
/// no [onPressed] it is dimmed and does none of this.
class ToolbarAction extends StatefulWidget {
  const ToolbarAction({super.key, required this.icon, required this.label, required this.onPressed});

  final QuantusIcons icon;
  final String label;

  /// What a press does. Null makes the action unavailable.
  final VoidCallback? onPressed;

  /// The box that draws the backing, and the one that draws the focus ring.
  static const backingKey = Key('toolbar-action-backing');
  static const focusRingKey = Key('toolbar-action-focus-ring');

  static const double height = 28;

  @override
  State<ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<ToolbarAction> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isAvailable => widget.onPressed != null;

  void _press() => widget.onPressed?.call();

  @override
  void didUpdateWidget(ToolbarAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isAvailable) _isPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.smBorder;
    final backing = !_isAvailable
        ? 0.0
        : _isPressed
        ? 0.14
        : _isHovered
        ? 0.08
        : 0.0;

    return Semantics(
      button: true,
      enabled: _isAvailable,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _isAvailable,
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _press())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _isAvailable ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: _isAvailable ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: _isAvailable ? () => setState(() => _isPressed = false) : null,
          onTap: widget.onPressed,
          child: Opacity(
            opacity: _isAvailable ? 1 : 0.4,
            child: DecoratedBox(
              key: ToolbarAction.focusRingKey,
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: _isFocused && _isAvailable
                    ? Border.all(color: colors.accentFlare.useOpacity(0.7), width: 2)
                    : null,
              ),
              child: DecoratedBox(
                key: ToolbarAction.backingKey,
                decoration: BoxDecoration(color: colors.textContent.useOpacity(backing), borderRadius: radius),
                child: SizedBox(
                  height: ToolbarAction.height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 7,
                      children: [
                        QuantusIcon(widget.icon, size: 16, color: colors.accentFlare),
                        Text(
                          widget.label,
                          style: context.themeTextV3.bodyEmphasis.copyWith(
                            height: 1,
                            color: colors.textWhite.useOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
