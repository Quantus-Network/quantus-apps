import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class Toaster extends StatelessWidget {
  final String message;
  final IconData iconData;
  final Color? iconColor;
  final Color? textColor;

  const Toaster({super.key, required this.message, required this.iconData, this.iconColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    final double iconSize = context.isTablet ? 18 : 14;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: ShapeDecoration(
        color: context.colors.toasterBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(35),
          side: BorderSide(color: context.colors.toasterBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: iconSize),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: context.themeText.detail?.copyWith(color: textColor), softWrap: true),
          ),
        ],
      ),
    );
  }
}
