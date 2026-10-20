import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';

class AccountBadge extends StatelessWidget {
  final String name;
  final bool isActive;
  final double size;
  final TextStyle? textStyle;
  final IconData? icon;

  /// Initials come from this address's checkphrase instead of [name].
  final String? checkphraseAddress;

  const AccountBadge({super.key, required this.name, this.isActive = false, this.size = 40, this.textStyle, this.icon})
    : checkphraseAddress = null;

  AccountBadge.account({super.key, required Account account, this.isActive = false, this.size = 40, this.textStyle})
    : name = account.name,
      icon = null,
      checkphraseAddress = null;

  const AccountBadge.icon({super.key, required this.icon, this.isActive = false, this.size = 40})
    : name = '',
      textStyle = null,
      checkphraseAddress = null;

  const AccountBadge.checkphrase({
    super.key,
    required String address,
    this.isActive = false,
    this.size = 40,
    this.textStyle,
  }) : name = '',
       icon = null,
       checkphraseAddress = address;

  static String _initials(String name) => getAccountBadgeInitials(name, separator: ' ');

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final foreground = isActive ? colors.accentFlare : colors.textMuted;
    final style = (textStyle ?? context.themeTextV3.labelMonogram).copyWith(color: foreground);
    final address = checkphraseAddress;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: colors.borderHairline),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: foreground)
          : address != null
          ? CheckphraseText(address, transform: (phrase) => _initials(phrase.replaceAll('-', ' ')), style: style)
          : Text(_initials(name), style: style),
    );
  }
}
