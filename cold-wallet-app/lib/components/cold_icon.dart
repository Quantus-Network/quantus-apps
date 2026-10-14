import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Glyphs from the Figma Cold Wallet page that the SDK icon set does not have.
enum ColdIcons {
  wifiSlash('assets/icons/wifi_slash.svg'),
  scan('assets/icons/scan.svg'),
  gear('assets/icons/gear.svg'),
  faceId('assets/icons/face_id.svg'),
  checkCircle('assets/icons/check_circle.svg'),
  key('assets/icons/key.svg'),
  warning('assets/icons/warning.svg'),
  warningCircle('assets/icons/warning_circle.svg');

  const ColdIcons(this.assetPath);

  final String assetPath;
}

/// [QuantusIcon] for [ColdIcons]. Defaults to [AppColorsV3.textMuted].
class ColdIcon extends StatelessWidget {
  final ColdIcons icon;
  final double size;
  final Color? color;

  const ColdIcon(this.icon, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        icon.assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color ?? context.colorsV3.textMuted, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}
