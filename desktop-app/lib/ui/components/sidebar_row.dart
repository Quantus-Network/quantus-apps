import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One selectable line of the sidebar: a title, with an optional line beneath
/// it and optional widgets before and after.
///
/// An account's row has its title in full strength. A row that is not an
/// account ([isSecondary]) is quieter until it is selected.
class SidebarRow extends StatelessWidget {
  const SidebarRow({
    super.key,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    this.isSecondary = false,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isSecondary;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final borderRadius = context.radiusV3.smBorder;
    final titleStyle = isSecondary
        ? text.body.copyWith(color: isSelected ? colors.textContent : colors.textMuted)
        : text.bodyEmphasis.copyWith(color: colors.textContent);

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              spacing: 10,
              children: [
                ?leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
