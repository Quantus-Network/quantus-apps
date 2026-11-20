import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A part of the window: a rounded, bordered box on the window's darker
/// ground, under a header line when it has a [title]. Panels stand [gap]
/// apart, and [gap] in from the window's edges.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.trailing, required this.child, this.fillsHeight = true});

  /// The space between panels, and between a panel and the window's edge.
  static const double gap = 8;

  /// The height of a panel's header line, above its hairline.
  static const double headerHeight = 40;

  /// The space between the header's ends and what it holds.
  static const double headerPadding = 16;

  /// What the panel holds, named in its header line.
  final String? title;

  /// What sits at the header line's end.
  final Widget? trailing;

  final Widget child;

  /// Whether [child] fills the panel's height under the header. Else the
  /// panel is as tall as [child].
  final bool fillsHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final title = this.title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.smBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: ClipRRect(
        borderRadius: context.radiusV3.smBorder,
        child: Column(
          mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              SizedBox(
                height: headerHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: headerPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.textContent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
              const MenuDivider(),
            ],
            if (fillsHeight) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
