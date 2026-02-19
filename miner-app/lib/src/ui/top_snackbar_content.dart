import 'package:flutter/material.dart';
import 'package:quantus_miner/src/shared/extensions/theme_extensions.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TopSnackBarContent extends StatelessWidget {
  final String title;
  final String message;
  final Icon? icon;

  const TopSnackBarContent({super.key, required this.title, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    // Default Icon if none provided
    final Widget displayIcon = Container(
      width: 36,
      height: 36,
      decoration: const ShapeDecoration(
        color: Color(0xFF494949), // Default grey background
        shape: OvalBorder(), // Use OvalBorder for circle
      ),
      alignment: Alignment.center,
      child: Icon(icon?.icon ?? Icons.check, color: icon?.color ?? Colors.white, size: 24), // Default check icon
    );

    return Container(
      // width: 343, // Width will be handled by the flash package's constraints
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecoration(
        color: Colors.grey.shade900, // White background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.white.useOpacity(0.1), width: 1),
        ),
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
                Text(title, style: context.textTheme.titleSmall),
                const SizedBox(height: 2), // Spacing
                Text(
                  message,
                  style: context.textTheme.bodySmall,

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
