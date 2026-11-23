import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Figma Cold Wallet avatar gradient. Its teal stops match no colour token and
/// cannot be mixed from one, so they live here and nowhere else.
const _avatarGradientTop = Color.fromRGBO(9, 26, 32, 0.5);
const _avatarGradientBottom = Color.fromRGBO(26, 79, 97, 0.5);

/// `qzX8…5rh2`: how every account row shortens an address.
String shortAddress(String address) =>
    AddressFormattingService.formatAddress(address, prefix: 4, ellipses: '…', postFix: 4);

/// Initials circle for an account row: 30pt in menus, 40pt in lists.
class AccountAvatar extends StatelessWidget {
  final String label;
  final double size;

  const AccountAvatar({super.key, required this.label, this.size = 40});

  /// First letters of the first two words, else the first two letters.
  static String initialsOf(String label) {
    final words = label.trim().split(RegExp(r'\s+'));
    final first = words.first;
    final initials = words.length > 1
        ? '${first[0]}${words[1][0]}'
        : first.substring(0, first.length < 2 ? first.length : 2);
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_avatarGradientTop, _avatarGradientBottom],
        ),
        border: Border.all(color: colors.borderHairline, width: 0.5),
      ),
      child: Text(
        initialsOf(label),
        style: context.themeTextV3.labelMonogram.copyWith(fontSize: size <= 30 ? 10 : 12, color: colors.accentFlare),
      ),
    );
  }
}
