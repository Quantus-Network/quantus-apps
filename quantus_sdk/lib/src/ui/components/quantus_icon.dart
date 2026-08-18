import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Glyphs from the v3 Figma interim icon set (Phosphor Light replacement pending).
enum QuantusIcons {
  kebab('assets/icons/kebab.svg'),
  chevronRight('assets/icons/chevron_right.svg'),
  chevronLeft('assets/icons/chevron_left.svg'),
  caretDown('assets/icons/caret_down.svg'),
  plus('assets/icons/plus.svg'),
  swapVertical('assets/icons/swap_vertical.svg'),
  lock('assets/icons/lock.svg');

  const QuantusIcons(this.assetPath);

  /// Package-relative SVG path for this glyph.
  final String assetPath;
}

/// Tinted 20px Figma glyph. Pass [color] to override [AppColorsV3.textMuted].
class QuantusIcon extends StatelessWidget {
  final QuantusIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  const QuantusIcon(this.icon, {super.key, this.size = 20, this.color, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final Color resolvedColor = color ?? context.colorsV3.textMuted;

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        icon.assetPath,
        package: 'quantus_sdk',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        excludeFromSemantics: semanticLabel == null,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}
