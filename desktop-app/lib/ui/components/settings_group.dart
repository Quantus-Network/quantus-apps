import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Rows grouped as macOS groups settings: a small capital [label] over a
/// rounded card whose rows are split by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.mdBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: CapsText(
            label,
            style: context.themeTextV3.dataAddress.copyWith(height: 1, letterSpacing: 1.4, color: colors.textMuted2),
          ),
        ),
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.borderHairline),
          ),
          // Clipped, so a row's hover backing keeps to the card's corners.
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: colors.bgSurface2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, row) in rows.indexed) ...[
                    if (index > 0) Divider(height: 1, indent: 16, endIndent: 16, color: colors.borderHairline),
                    row,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A row of a [SettingsGroup]: a title over a muted line.
///
/// [SettingsRow.action] opens something, and shows a chevron. It behaves as
/// the header's actions do: a backing under the cursor, stronger while
/// pressed; Tab reaches it, a ring shows the focus, Space or Return presses
/// it; a screen reader can press it. With no `onPressed` it is dimmed and
/// does none of this.
///
/// [SettingsRow.control] holds a control of its own at its end, and is not
/// pressed itself.
class SettingsRow extends StatefulWidget {
  const SettingsRow.action({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.isDestructive = false,
  }) : trailing = null,
       _isAction = true;

  const SettingsRow.control({super.key, required this.title, required this.subtitle, required Widget this.trailing})
    : onPressed = null,
      isDestructive = false,
      _isAction = false;

  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  /// Draws the title and chevron in the warning colour.
  final bool isDestructive;

  final Widget? trailing;
  final bool _isAction;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isAvailable => widget.onPressed != null;

  void _press() => widget.onPressed?.call();

  @override
  void didUpdateWidget(SettingsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isAvailable) _isPressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final accent = widget.isDestructive ? colors.semanticEmber : null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: text.bodyEmphasis.copyWith(color: accent ?? colors.textContent)),
                const SizedBox(height: 3),
                Text(widget.subtitle, style: text.body.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          widget.trailing ?? Icon(CupertinoIcons.chevron_forward, size: 14, color: accent ?? colors.textMuted2),
        ],
      ),
    );

    if (!widget._isAction) return content;

    final backing = !_isAvailable
        ? 0.0
        : _isPressed
        ? 0.10
        : _isHovered
        ? 0.05
        : 0.0;

    return Semantics(
      button: true,
      enabled: _isAvailable,
      label: widget.title,
      hint: widget.subtitle,
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
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: _isFocused && _isAvailable
                    ? Border.all(color: colors.accentFlare.useOpacity(0.7), width: 2)
                    : null,
              ),
              child: ColoredBox(color: colors.textContent.useOpacity(backing), child: content),
            ),
          ),
        ),
      ),
    );
  }
}
