import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The badge that stands for [account]: the lock for the encrypted account,
/// which is always told apart, and the account's initials for any other.
class DesktopAccountBadge extends StatelessWidget {
  const DesktopAccountBadge({super.key, required this.account, required this.size});

  final BaseAccount account;
  final double size;

  @override
  Widget build(BuildContext context) {
    return isEncryptedAccount(account) ? EncryptedLockBadge(size: size) : AccountBadge(name: account.name, size: size);
  }
}
