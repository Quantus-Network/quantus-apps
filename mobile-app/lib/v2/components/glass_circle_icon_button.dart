import 'package:flutter/material.dart';

class GlassCircleIconButton extends StatelessWidget {
  static const _bgAsset = 'assets/v2/glass_circle_icon_button_bg.png';

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color iconColor;
  final bool filled;

  const GlassCircleIconButton({
    super.key,
    required this.icon,
    required this.iconColor,
    this.onTap,
    this.size = 48,
    this.iconSize = 20,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: filled ? 1 : 0.92,
              child: Image.asset(_bgAsset, fit: BoxFit.cover),
            ),
            Center(
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
          ],
        ),
      ),
    );
  }
}
