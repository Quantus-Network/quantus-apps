import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AccountBadge extends StatelessWidget {
  final Account account;
  final bool isActive;
  final double size;
  final TextStyle? textStyle;

  const AccountBadge({super.key, required this.account, this.isActive = false, this.size = 40, this.textStyle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = getAccountBadgeInitials(account.name, separator: ' ');
    final effectiveTextStyle = textStyle ?? context.themeText.transactionDetailRowValue?.copyWith(letterSpacing: -0.25);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(size / 2)),
      child: Text(label, style: effectiveTextStyle?.copyWith(color: isActive ? colors.accentOrange : colors.textLabel)),
    );
  }
}
