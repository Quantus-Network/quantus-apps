import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class TopSnackBarContent extends StatelessWidget {
  final String title;
  final String message;
  final Widget? icon;

  const TopSnackBarContent({super.key, required this.title, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    // Default Icon if none provided
    final Widget displayIcon =
        icon ??
        Container(
          width: context.isTablet ? 44 : 36,
          height: context.isTablet ? 44 : 36,
          decoration: const ShapeDecoration(
            color: Color(0xFF494949), // Default grey background
            shape: OvalBorder(), // Use OvalBorder for circle
          ),
          alignment: Alignment.center,
          child: Icon(Icons.check, color: Colors.white, size: context.isTablet ? 24 : 20), // Default check icon
        );

    return Container(
      // width: 343, // Width will be handled by the flash package's constraints
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecoration(
        color: Colors.white, // White background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        // Optional shadow for better visibility
        shadows: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          displayIcon, // Use the provided or default icon
          const SizedBox(width: 16), // Spacing
          Expanded(
            // Allow text to wrap
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.textSecondary),
                ),
                const SizedBox(height: 2), // Spacing
                Text(
                  message,
                  style: context.themeText.detail?.copyWith(color: Colors.black.useOpacity(0.6)),
                  // softWrap: true, // Ensure message wraps
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
