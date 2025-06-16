import 'package:flutter/material.dart';
import '../extensions/color_extensions.dart';

class TopSnackBarContent extends StatelessWidget {
  final String title;
  final String message;
  final Widget? icon;

  const TopSnackBarContent({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Default Icon if none provided
    final Widget displayIcon = icon ??
        Container(
          width: 36,
          height: 36,
          decoration: const ShapeDecoration(
            color: Color(0xFF494949), // Default grey background
            shape: OvalBorder(), // Use OvalBorder for circle
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, color: Colors.white, size: 20), // Default check icon
        );

    return Container(
      // width: 343, // Width will be handled by the flash package's constraints
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecoration(
          color: Colors.white, // White background
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          // Optional shadow for better visibility
          shadows: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ]),
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
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w500, // Slightly bolder title
                  ),
                ),
                const SizedBox(height: 2), // Spacing
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.black.useOpacity(153 / 255.0), // Black with alpha
                    fontSize: 12,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400, // Regular weight for message
                  ),
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
