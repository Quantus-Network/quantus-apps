import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class ListItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showArrow;

  const ListItem({super.key, required this.title, required this.onTap, this.trailing, this.showArrow = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: context.isTablet ? 16 : 12, horizontal: 18),
        decoration: ShapeDecoration(
          color: context.themeColors.buttonGlass,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: context.themeText.smallParagraph),
            trailing ??
                (showArrow
                    ? Icon(Icons.arrow_forward_ios, size: context.themeSize.settingMenuIconSize)
                    : const SizedBox()),
          ],
        ),
      ),
    );
  }
}
