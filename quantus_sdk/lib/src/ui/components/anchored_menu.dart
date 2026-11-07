import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AnchoredMenuItem {
  final String label;

  /// Null leaves the item visible but inert.
  final VoidCallback? onTap;
  final bool isDestructive;

  /// Secondary row such as "Manage accounts".
  final bool isMuted;

  /// Explains an inert item, under its label.
  final String? caption;
  final Widget? leading;
  final String? subtitle;
  final bool isSelected;

  const AnchoredMenuItem({
    required this.label,
    this.onTap,
    this.isDestructive = false,
    this.isMuted = false,
    this.caption,
    this.leading,
    this.subtitle,
    this.isSelected = false,
  });
}

/// Opens a dropdown under [anchor] over an 80% scrim. Each group is separated
/// by a hairline; tapping an item closes the menu before running its action.
Future<void> showAnchoredMenu(
  BuildContext context, {
  required BuildContext anchor,
  required List<List<AnchoredMenuItem>> groups,
  double width = 262,
}) {
  final navigator = Navigator.of(context);
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  return navigator.push(
    _AnchoredMenuRoute(
      anchor: topLeft & box.size,
      groups: groups,
      width: width,
      scrimColor: context.colorsV3.bgVoid.useOpacity(0.8),
    ),
  );
}

class _AnchoredMenuRoute extends PopupRoute<void> {
  final Rect anchor;
  final List<List<AnchoredMenuItem>> groups;
  final double width;
  final Color scrimColor;

  _AnchoredMenuRoute({required this.anchor, required this.groups, required this.width, required this.scrimColor});

  @override
  Color? get barrierColor => scrimColor;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Material(
      type: MaterialType.transparency,
      child: CustomSingleChildLayout(
        delegate: _AnchoredMenuLayout(anchor: anchor, width: width),
        child: _AnchoredMenuPanel(groups: groups),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> _, Widget child) =>
      FadeTransition(opacity: animation, child: child);
}

class _AnchoredMenuLayout extends SingleChildLayoutDelegate {
  static const _gap = 8.0;
  static const _margin = 24.0;

  final Rect anchor;
  final double width;

  const _AnchoredMenuLayout({required this.anchor, required this.width});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
    minWidth: width,
    maxWidth: width,
    maxHeight: math.max(0, constraints.maxHeight - anchor.bottom - _gap - _margin),
  );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - _margin - childSize.width;
    final left = anchor.left + childSize.width > size.width - _margin ? anchor.right - childSize.width : anchor.left;
    return Offset(math.max(math.min(left, maxLeft), _margin), anchor.bottom + _gap);
  }

  @override
  bool shouldRelayout(_AnchoredMenuLayout oldDelegate) => oldDelegate.anchor != anchor || oldDelegate.width != width;
}

class _AnchoredMenuPanel extends StatelessWidget {
  final List<List<AnchoredMenuItem>> groups;

  const _AnchoredMenuPanel({required this.groups});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.bgCardGradientTop, colors.bgCardGradientBottom],
        ),
        border: Border.all(color: colors.borderHairline, width: 0.5),
        boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.6), blurRadius: 40, offset: const Offset(0, 20))],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, group) in groups.indexed) ...[
              if (index > 0)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: colors.borderHairline,
                ),
              for (final item in group) _AnchoredMenuRow(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnchoredMenuRow extends StatelessWidget {
  final AnchoredMenuItem item;

  const _AnchoredMenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final enabled = item.onTap != null;
    final base = item.isDestructive
        ? colors.semanticEmber
        : item.isMuted
        ? colors.textMuted
        : colors.textContent;
    final labelColor = enabled ? base : base.useOpacity(0.4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              Navigator.pop(context);
              item.onTap!();
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: item.leading == null ? 18 : 14),
        decoration: BoxDecoration(
          color: item.isSelected ? colors.textWhite.useOpacity(0.07) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            if (item.leading != null) ...[item.leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: (item.isMuted ? text.body : text.bodyLarge).copyWith(color: labelColor)),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(item.subtitle!, style: text.dataAddress.copyWith(color: colors.textMuted2)),
                  ],
                  if (item.caption != null) ...[
                    const SizedBox(height: 4),
                    Text(item.caption!, style: text.caption.copyWith(color: colors.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
