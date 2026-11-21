import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// One item of an account's menu.
enum AccountMenuItem { showAddress, innerHash, rename, recoveryPhrase, multisigDetails, disconnect }

/// What a multisig's menu offers, in display order.
const multisigMenu = [
  AccountMenuItem.showAddress,
  AccountMenuItem.rename,
  AccountMenuItem.multisigDetails,
  AccountMenuItem.disconnect,
];

/// What [account]'s menu offers, in display order; [accounts] are all the
/// accounts stored in this app.
///
/// An encrypted account offers only its inner hash. Other accounts show their
/// address and can be renamed; a local one also shows its wallet's recovery
/// phrase. Disconnect comes last, where [disconnectPlanOf] allows it.
List<AccountMenuItem> accountMenuOf(Account account, List<Account> accounts) {
  if (account.accountType == AccountType.encrypted) return const [AccountMenuItem.innerHash];
  return [
    AccountMenuItem.showAddress,
    AccountMenuItem.rename,
    if (account.accountType == AccountType.local) AccountMenuItem.recoveryPhrase,
    if (disconnectPlanOf(account, accounts) != null) AccountMenuItem.disconnect,
  ];
}

/// How [account] is disconnected.
sealed class DisconnectPlan {
  const DisconnectPlan(this.account);

  final Account account;
}

/// Only [account] goes; its wallet and recovery phrase stay.
final class DisconnectAccount extends DisconnectPlan {
  const DisconnectAccount(super.account);

  @override
  bool operator ==(Object other) => other is DisconnectAccount && other.account.accountId == account.accountId;

  @override
  int get hashCode => account.accountId.hashCode;
}

/// A hardware account goes; nothing of it is stored in this app.
final class DisconnectHardware extends DisconnectPlan {
  const DisconnectHardware(super.account);

  @override
  bool operator ==(Object other) => other is DisconnectHardware && other.account.accountId == account.accountId;

  @override
  int get hashCode => account.accountId.hashCode;
}

/// [account] is its wallet's last, so the whole wallet goes with it, recovery
/// phrase included. [walletNumber] is how the wallet is named to the user.
final class DisconnectWallet extends DisconnectPlan {
  const DisconnectWallet(super.account, {required this.walletIndex, required this.walletNumber});

  final int walletIndex;
  final int walletNumber;

  @override
  bool operator ==(Object other) =>
      other is DisconnectWallet &&
      other.account.accountId == account.accountId &&
      other.walletIndex == walletIndex &&
      other.walletNumber == walletNumber;

  @override
  int get hashCode => Object.hash(account.accountId, walletIndex, walletNumber);

  @override
  String toString() => 'DisconnectWallet(${account.accountId}, walletIndex: $walletIndex, walletNumber: $walletNumber)';
}

/// How [account] is disconnected, or null when it cannot be; [accounts] are all
/// the accounts stored in this app, [account] among them.
///
/// A hardware account always can be. An encrypted or external one cannot. A local
/// account goes alone while its wallet keeps another (non-encrypted) account,
/// and otherwise takes its wallet with it, except the primary wallet (index 0),
/// which is only removed by resetting the app.
DisconnectPlan? disconnectPlanOf(Account account, List<Account> accounts) {
  if (!accounts.any((a) => a.accountId == account.accountId)) {
    throw ArgumentError.value(account.accountId, 'account', 'is not among the accounts');
  }
  switch (account.accountType) {
    case AccountType.keystone:
      return DisconnectHardware(account);
    case AccountType.encrypted || AccountType.external:
      return null;
    case AccountType.local:
      final siblings = accounts.where(
        (a) => a.walletIndex == account.walletIndex && a.accountType != AccountType.encrypted,
      );
      if (siblings.length > 1) return DisconnectAccount(account);
      if (account.walletIndex == 0) return null;
      return DisconnectWallet(
        account,
        walletIndex: account.walletIndex,
        walletNumber: softwareWalletNumber(accounts, account.walletIndex)!,
      );
  }
}

/// [multisig]'s signers in display order: its creator first when the creator
/// is one of them, the rest as stored.
List<String> orderedSignersOf(MultisigAccount multisig) {
  final creator = multisig.creator;
  if (creator == null || !multisig.signers.contains(creator)) return List.of(multisig.signers);
  return [creator, ...multisig.signers.where((id) => id != creator)];
}

/// What a name typed over [current] amounts to.
@immutable
sealed class NameEdit {
  const NameEdit();
}

final class NameBlank extends NameEdit {
  const NameBlank();

  @override
  bool operator ==(Object other) => other is NameBlank;

  @override
  int get hashCode => 0;
}

final class NameUnchanged extends NameEdit {
  const NameUnchanged();

  @override
  bool operator ==(Object other) => other is NameUnchanged;

  @override
  int get hashCode => 1;
}

final class NameChanged extends NameEdit {
  const NameChanged(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is NameChanged && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'NameChanged($name)';
}

/// What typing [entered] over the name [current] amounts to: the name is
/// trimmed, and a blank one cannot be saved.
NameEdit nameEditOf(String current, String entered) {
  final name = entered.trim();
  if (name.isEmpty) return const NameBlank();
  if (name == current) return const NameUnchanged();
  return NameChanged(name);
}
