import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Title bar with equal [AppBackButton.hitSize] side slots so the title stays
/// centred whatever sits in them. Default padding keeps the bar 76pt tall.
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
    this.padding = const EdgeInsets.only(top: 6.0, bottom: 22.0),
  });

  Widget _slot(Widget? child, Alignment alignment) => SizedBox(
    width: AppBackButton.hitSize,
    height: AppBackButton.hitSize,
    child: child == null ? null : Align(alignment: alignment, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    final leftWidget = leading ?? (showBackButton ? const AppBackButton() : null);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          _slot(leftWidget, Alignment.centerLeft),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleScreen.copyWith(color: colors.textContent),
              ),
            ),
          ),
          _slot(trailing, Alignment.centerRight),
        ],
      ),
    );
  }
}
