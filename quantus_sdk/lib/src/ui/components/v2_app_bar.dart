import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    Widget leftWidget = leading ?? (showBackButton ? const AppBackButton() : const SizedBox(width: 24));
    Widget rightWidget = trailing ?? const SizedBox(width: 24);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leftWidget,
          Text(title, style: text.titleScreen.copyWith(color: colors.textContent)),
          rightWidget,
        ],
      ),
    );
  }
}
