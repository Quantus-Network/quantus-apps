import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_cold_wallet/components/glass_button_base.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AppBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final double containerSize = 28;
    final double iconSize = 24;

    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      child: GlassButtonBase(
        buttonHeight: containerSize,
        buttonWidth: containerSize,
        borderRadius: BorderRadius.circular(containerSize / 2),
        padding: const EdgeInsets.all(2),
        child: SvgPicture.asset(
          'assets/v2/caret_left.svg',
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(context.colors.textPrimary, BlendMode.srcIn),
        ),
      ),
    );
  }
}
