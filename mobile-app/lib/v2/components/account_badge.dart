import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AccountBadge extends StatelessWidget {
  final String name;
  final bool isActive;
  final double size;
  final TextStyle? textStyle;
  final IconData? icon;

  const AccountBadge({super.key, required this.name, this.isActive = false, this.size = 40, this.textStyle, this.icon});

  AccountBadge.account({super.key, required Account account, this.isActive = false, this.size = 40, this.textStyle})
    : name = account.name,
      icon = null;

  const AccountBadge.icon({super.key, required this.icon, this.isActive = false, this.size = 40})
    : name = '',
      textStyle = null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = isActive ? colors.accentOrange : colors.textLabel;
    final effectiveTextStyle = textStyle ?? context.themeText.transactionDetailRowValue?.copyWith(letterSpacing: -0.25);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(size / 2)),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: foreground)
          : Text(
              getAccountBadgeInitials(name, separator: ' '),
              style: effectiveTextStyle?.copyWith(color: foreground),
            ),
    );
  }
}
