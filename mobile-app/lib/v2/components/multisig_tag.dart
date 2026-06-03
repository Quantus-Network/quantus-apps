import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MultisigTag extends StatelessWidget {
  final String label;

  const MultisigTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderButton.useOpacity(0.5)),
      ),
      child: Text(
        label,
        style: context.themeText.detail?.copyWith(
          color: colors.checksum,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
