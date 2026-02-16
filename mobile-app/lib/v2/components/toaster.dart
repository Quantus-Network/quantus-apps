import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class Toaster extends StatelessWidget {
  final String message;
  final IconData iconData;
  final Color? iconColor;

  const Toaster({super.key, required this.message, required this.iconData, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final double iconSize = context.isTablet ? 20 : 16;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: ShapeDecoration(
        color: context.colors.toasterBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.22),
          side: BorderSide(color: context.colors.toasterBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: iconSize),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: context.themeText.smallParagraph, softWrap: true)),
        ],
      ),
    );
  }
}
