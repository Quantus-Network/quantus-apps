import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The surface every menu the app draws itself sits on (a pop-up button's
/// menu, a context menu): a raised, bordered panel holding its rows.
class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key, required this.children, this.minWidth = 0, this.scrolls = false});

  final List<Widget> children;

  /// The narrowest the panel is; it is as wide as its widest row otherwise.
  final double minWidth;

  /// Whether the rows scroll when there are more than the panel can show.
  final bool scrolls;

  /// The space above the first row and below the last.
  static const double padding = 5;

  /// How far a row's highlight sits from the panel's edges.
  static const double rowInset = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.smBorder;
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

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
              child: scrolls ? SingleChildScrollView(child: rows) : rows,
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of a [MenuPanel]: a check mark's place, the label, and a chevron
/// when it opens a submenu. The
/// highlighted row is filled with the accent; a destructive item's label is
/// ember; a disabled item's is dimmed.
class MenuPanelRow extends StatelessWidget {
  const MenuPanelRow({
    super.key,
    required this.label,
    this.isHighlighted = false,
    this.isChecked = false,
    this.isDestructive = false,
    this.isDisabled = false,
    this.hasSubmenu = false,
  });

  final String label;
  final bool isHighlighted;
  final bool isChecked;
  final bool isDestructive;
  final bool isDisabled;

  /// Shows the chevron of an item that opens a submenu.
  final bool hasSubmenu;

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
    final color = isDisabled
        ? colors.textMuted2
        : isHighlighted
        ? colors.textVoid
        : isDestructive
        ? colors.semanticEmber
        : colors.textContent;

    return Semantics(
      container: isDisabled,
      enabled: isDisabled ? false : null,
      child: Padding(
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
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: text.body.copyWith(height: 1, color: color),
                    ),
                  ),
                  if (hasSubmenu) ...[
                    const SizedBox(width: 20),
                    Icon(CupertinoIcons.chevron_right, size: 11, color: color),
                  ],
                ],
              ),
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
