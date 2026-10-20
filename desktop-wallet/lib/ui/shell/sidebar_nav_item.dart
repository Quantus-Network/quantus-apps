import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SidebarNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String shortcut;
  final bool selected;
  final VoidCallback onTap;

  const SidebarNavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.shortcut,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final radius = context.radiusV3;
    final color = selected ? colors.textContent : colors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Tooltip(
        message: shortcut,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: selected ? colors.bgSurface2 : Colors.transparent,
          borderRadius: radius.smBorder,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius.smBorder,
            hoverColor: colors.bgSurface2,
            focusColor: colors.accentFlare.useOpacity(0.12),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: selected ? colors.accentFlare : Colors.transparent,
                      borderRadius: radius.xsBorder,
                    ),
                  ),
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Text(label, style: text.body.copyWith(color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
