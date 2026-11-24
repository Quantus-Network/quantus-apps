import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The surface every menu the app draws itself sits on (a pop-up button's
/// menu, a context menu): a raised, bordered panel holding its rows.
class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key, required this.children, this.minWidth = 0});

  final List<Widget> children;

  /// The narrowest the panel is; it is as wide as its widest row otherwise.
  final double minWidth;

  /// The space above the first row and below the last.
  static const double padding = 5;

  /// How far a row's highlight sits from the panel's edges.
  static const double rowInset = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.smBorder;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: IntrinsicWidth(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.borderEmphasis),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgSurface2,
              borderRadius: radius,
              boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of a [MenuPanel]: a check mark's place and the label. The
/// highlighted row is filled with the accent; a destructive item's label is
/// ember.
class MenuPanelRow extends StatelessWidget {
  const MenuPanelRow({
    super.key,
    required this.label,
    this.isHighlighted = false,
    this.isChecked = false,
    this.isDestructive = false,
  });

  final String label;
  final bool isHighlighted;
  final bool isChecked;
  final bool isDestructive;

  static const double height = 22;

  /// The space a row keeps for its check mark, checked or not.
  static const double checkmarkWidth = 18;

  /// How far a row's content sits inside its highlight.
  static const double contentPadding = 6;

  /// How far a row's label sits from the panel's left edge.
  static const double labelInset = MenuPanel.rowInset + contentPadding + checkmarkWidth;

  static const checkmarkKey = Key('menu-panel-checkmark');

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final color = isHighlighted
        ? colors.textVoid
        : isDestructive
        ? colors.semanticEmber
        : colors.textContent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MenuPanel.rowInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isHighlighted ? colors.accentFlare : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: contentPadding, right: 14),
            child: Row(
              children: [
                SizedBox(
                  width: checkmarkWidth,
                  child: isChecked
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(CupertinoIcons.checkmark_alt, key: checkmarkKey, size: 13, color: color),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(label, style: text.body.copyWith(height: 1, color: color)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A line between two groups of a [MenuPanel]'s rows.
class MenuPanelSeparator extends StatelessWidget {
  const MenuPanelSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      child: Container(height: 1, color: context.colorsV3.borderHairline),
    );
  }
}
