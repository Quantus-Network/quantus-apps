import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class Toaster extends StatelessWidget {
  final String message;
  final Icon? icon;

  const Toaster({super.key, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    final Widget displayIcon = Icon(
      icon?.icon ?? Icons.copy,
      color: icon?.color ?? Colors.white,
      size: context.isTablet ? 20 : 16,
    );

    return Container(
      // width: 343, // Width will be handled by the flash package's constraints
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: ShapeDecoration(
        color: context.colors.toasterBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.22),
          side: BorderSide(color: context.colors.toasterBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          displayIcon,
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: context.themeText.smallParagraph, softWrap: true)),
        ],
      ),
    );
  }
}
