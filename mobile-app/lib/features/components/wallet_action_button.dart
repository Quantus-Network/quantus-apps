import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';

class WalletActionButton extends StatelessWidget {
  final String assetPath;
  const WalletActionButton({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: SvgPicture.asset(
        assetPath,
        width: context.themeSize.mainMenuIconSize,
        height: context.themeSize.mainMenuIconSize,
      ),
    );
  }
}
