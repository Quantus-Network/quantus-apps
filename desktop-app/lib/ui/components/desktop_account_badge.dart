import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The badge that stands for [account]: the lock for the encrypted account,
/// which is always told apart, and the account's initials for any other.
///
/// What is inside grows with the badge: the lock is half of it, and the
/// initials are 10pt beside a line of text (24) and 12pt in the sidebar (32),
/// never under the 10pt the desktop allows.
class DesktopAccountBadge extends StatelessWidget {
  const DesktopAccountBadge({super.key, required this.account, required this.size});

  final BaseAccount account;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isEncryptedAccount(account)) return EncryptedLockBadge(size: size, iconSize: size / 2);
    return AccountBadge(
      name: account.name,
      size: size,
      textStyle: context.themeTextV3.labelMonogram.copyWith(fontSize: math.max(10, size * 0.375)),
    );
  }
}
