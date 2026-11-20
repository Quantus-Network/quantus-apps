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
  const ToolbarAction({
    super.key,
    required QuantusIcons this.icon,
    required this.label,
    required this.onPressed,
    this.iconOnly = false,
  }) : symbol = null;

  /// An action drawn with a system [symbol] where the app has no icon of its
  /// own; it looks and behaves as any other.
  const ToolbarAction.symbol({
    super.key,
    required IconData this.symbol,
    required this.label,
    required this.onPressed,
    this.iconOnly = false,
  }) : icon = null;

  /// The app's icon, or else [symbol]: exactly one of them is set.
  final QuantusIcons? icon;
  final IconData? symbol;
  final String label;

  /// What a press does. Null makes the action unavailable.
  final VoidCallback? onPressed;

  /// Draws the icon alone, muted, as a panel's header holds its actions;
  /// [label] is still what a screen reader says.
  final bool iconOnly;

  /// The box that draws the backing, and the one that draws the focus ring.
  static const backingKey = Key('toolbar-action-backing');
  static const focusRingKey = Key('toolbar-action-focus-ring');

  static const double height = 28;

  /// The room on each side of the icon and label, which the backing fills.
  static const double inset = 10;

  @override
  State<ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<ToolbarAction> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  static const double _iconSize = 16;

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
    final iconColor = widget.iconOnly ? colors.textMuted : colors.accentFlare;
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
      // The children's semantics are left out, their tap with them, so the
      // press a screen reader makes is offered here.
      onTap: _isAvailable ? _press : null,
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
                    padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 6 : ToolbarAction.inset),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 7,
                      children: [
                        if (widget.icon case final icon?)
                          QuantusIcon(icon, size: _iconSize, color: iconColor)
                        else
                          Icon(widget.symbol, size: _iconSize, color: iconColor),
                        if (!widget.iconOnly)
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

/// The edge a [ToolbarActionRow] keeps to.
enum ToolbarActionEdge { leading, trailing }

/// Toolbar actions in a row held against an [edge] of the content: the outer
/// action's icon (leading) or label (trailing) lies on the edge, as text
/// would. Its backing reaches past the edge into the margin; clicks there
/// miss, since the content's bounds end at the edge.
class ToolbarActionRow extends StatelessWidget {
  const ToolbarActionRow({super.key, required this.edge, required this.children, this.spacing = 4, this.wraps = false});

  final ToolbarActionEdge edge;
  final List<Widget> children;
  final double spacing;

  /// Whether actions that do not fit on one line go on to the next, as in a
  /// narrow panel, rather than all staying on one.
  final bool wraps;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(edge == ToolbarActionEdge.trailing ? ToolbarAction.inset : -ToolbarAction.inset, 0),
      child: wraps
          ? Wrap(spacing: spacing, runSpacing: spacing, children: children)
          : Row(mainAxisSize: MainAxisSize.min, spacing: spacing, children: children),
    );
  }
}
