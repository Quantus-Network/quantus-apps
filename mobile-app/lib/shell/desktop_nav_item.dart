import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A single navigation row in the desktop sidebar.
class DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const DesktopNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final bgColor = isSelected ? colors.bgSurface2 : Colors.transparent;
    final fgColor = isSelected ? colors.textContent : colors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: bgColor,
        borderRadius: context.radiusV3.smBorder,
        child: InkWell(
          borderRadius: context.radiusV3.smBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: fgColor, size: 18),
                const SizedBox(width: 12),
                Text(label, style: text.body.copyWith(color: fgColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
