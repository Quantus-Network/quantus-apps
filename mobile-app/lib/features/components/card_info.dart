import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/label.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class CardInfo extends StatelessWidget {
  final String text;
  final Icon icon;
  final String? label;
  final VoidCallback? onPressed;
  final Color? textColor;

  const CardInfo({
    super.key,
    required this.text,
    required this.icon,
    this.label,
    this.onPressed,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final double verticalPadding = context.isTablet ? 12 : 8;

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[Label(label!), const SizedBox(height: 4)],
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: verticalPadding,
              left: 10,
              right: 18,
              bottom: verticalPadding,
            ),
            decoration: BoxDecoration(color: context.themeColors.buttonGlass),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: context.isTablet ? 660 : 251,
                  child: Text(
                    text,
                    style: context.themeText.smallParagraph?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
                icon,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
