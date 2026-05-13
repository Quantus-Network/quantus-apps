import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MultisigBadge extends StatelessWidget {
  final MultisigAccount account;
  final bool isActive;
  final double size;
  final TextStyle? textStyle;

  const MultisigBadge({super.key, required this.account, this.isActive = false, this.size = 40, this.textStyle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effective = textStyle ?? context.themeText.transactionDetailRowValue?.copyWith(letterSpacing: -0.25);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: colors.borderButton.useOpacity(0.5)),
      ),
      child: Text(
        '${account.threshold}/${account.signers.length}',
        style: effective?.copyWith(
          color: isActive ? colors.accentOrange : colors.textLabel,
          fontSize: size * 0.32,
          fontFamily: AppTextTheme.fontFamilySecondary,
        ),
      ),
    );
  }
}

class MultisigTag extends StatelessWidget {
  const MultisigTag({super.key});

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
        'MULTISIG',
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
