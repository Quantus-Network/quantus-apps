import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_screen.dart';

class OpenAccountsManagementButton extends StatelessWidget {
  const OpenAccountsManagementButton({super.key});

  @override
  Widget build(BuildContext context) {
    final double buttonHeight = 44;
    final BorderRadius borderRadius = context.radiusV3.pillBorder;
    final double iconSize = 20;

    return GestureDetector(
      onTap: () => openAccountsScreen(context),
      child: GlassButtonBase(
        buttonHeight: buttonHeight,
        borderRadius: borderRadius,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            SvgPicture.asset('assets/v2/uppercase_q.svg', width: iconSize, height: iconSize),
            const SizedBox(width: 14),
            RotatedBox(
              quarterTurns: -1,
              child: SvgPicture.asset(
                'assets/v2/caret_left.svg',
                width: iconSize,
                height: iconSize,
                colorFilter: ColorFilter.mode(context.colorsV3.textContent, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
