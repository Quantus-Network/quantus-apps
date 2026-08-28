import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class Toaster extends StatelessWidget {
  final String message;
  final IconData iconData;
  final Color iconColor;
  final Color textColor;

  const Toaster({
    super.key,
    required this.message,
    required this.iconData,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final double iconSize = context.isTablet ? 18 : 14;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: ShapeDecoration(
        color: colors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: context.radiusV3.pillBorder,
          side: BorderSide(color: colors.borderHairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: iconSize),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: text.caption.copyWith(color: textColor), softWrap: true),
          ),
        ],
      ),
    );
  }
}
