import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/components/back_button.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class V2AppBar extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool showBackButton;
  final EdgeInsetsGeometry padding;

  const V2AppBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.showBackButton = true,
    this.padding = const EdgeInsets.only(top: 16.0, bottom: 32.0),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    Widget leftWidget = leading ?? (showBackButton ? const AppBackButton() : const SizedBox(width: 24));
    Widget rightWidget = trailing ?? const SizedBox(width: 24);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leftWidget,
          Text(title, style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
          rightWidget,
        ],
      ),
    );
  }
}
