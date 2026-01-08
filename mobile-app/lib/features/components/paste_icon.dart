import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';

class PasteIcon extends StatelessWidget {
  final double? width;
  final Color? color;

  const PasteIcon({super.key, this.width, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/paste_icon_1.svg',
      width: width ?? context.themeSize.pasteIconSize,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
