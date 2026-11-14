import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One selectable line of the sidebar: a title, with an optional line beneath
/// it and optional widgets before and after.
class SidebarRow extends StatelessWidget {
  const SidebarRow({
    super.key,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final borderRadius = context.radiusV3.smBorder;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? colors.bgSurface2 : Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              spacing: 8,
              children: [
                ?leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        style: context.themeTextV3.body.copyWith(color: colors.textContent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      ?subtitle,
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
