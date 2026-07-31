import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Centered tappable underlined text, used for secondary actions under a
/// primary button (e.g. "Cancel Transaction").
class UnderlinedTextLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const UnderlinedTextLink({super.key, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(
          label,
          style: context.themeText.smallParagraph?.copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}
