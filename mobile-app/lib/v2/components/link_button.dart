import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Underlined inline text action, e.g. Max or Retry next to a value.
class LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const LinkButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return IntrinsicWidth(
      child: QuantusButton.simple(
        label: label,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        variant: ButtonVariant.ghost,
        textStyle: context.themeTextV3.body.copyWith(
          color: colors.accentFlare,
          decoration: TextDecoration.underline,
          decorationColor: colors.accentFlare,
        ),
      ),
    );
  }
}
