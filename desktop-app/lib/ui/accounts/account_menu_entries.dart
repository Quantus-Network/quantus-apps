import 'package:flutter/foundation.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/account_menu.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// One item of an account's menu, as the context menu and the menu bar's
/// Account menu both offer it.
@immutable
class AccountMenuEntry {
  const AccountMenuEntry(this.label, {required this.onSelected, this.command, this.isDestructive = false});

  final String label;
  final VoidCallback onSelected;

  /// The command whose shortcut the item answers to, if any.
  final AppCommand? command;
  final bool isDestructive;
}

/// What [account]'s menu offers, in the Mac's words, grouped: a null entry
/// is a separator. What it offers is wallet_core's rule ([accountMenuOf],
/// [multisigMenu]); [accounts] are all the accounts stored in this app.
///
/// The phone's "Show address" is Get Info and Copy Address here, and its
/// "Inner hash" Get Info and Copy Inner Hash; the items that open a step end
/// in "…", and Disconnect comes last, alone.
List<AccountMenuEntry?> accountMenuEntries(
  AppLocalizations l10n,
  BaseAccount account,
  List<Account> accounts,
  AccountManager manager,
) {
  final items = switch (account) {
    final Account account => accountMenuOf(account, accounts),
    MultisigAccount() => multisigMenu,
    _ => throw StateError('${account.accountId} has no menu'),
  };
  final getInfo = AccountMenuEntry(
    l10n.desktopAccountGetInfo,
    command: AppCommand.getInfo,
    onSelected: () => manager.openInfo(account),
  );

  final first = [
    if (items.contains(AccountMenuItem.showAddress)) ...[
      getInfo,
      AccountMenuEntry(
        l10n.desktopAccountCopyAddress,
        command: AppCommand.copyAddress,
        onSelected: () => manager.copy(account, CopiedValue.address),
      ),
    ],
    if (items.contains(AccountMenuItem.innerHash)) ...[
      getInfo,
      AccountMenuEntry(
        l10n.desktopAccountCopyInnerHash,
        onSelected: () => manager.copy(account, CopiedValue.innerHash),
      ),
    ],
  ];
  final second = [
    if (items.contains(AccountMenuItem.rename))
      AccountMenuEntry(l10n.desktopAccountRename, onSelected: () => manager.startRename(account)),
    if (items.contains(AccountMenuItem.recoveryPhrase))
      AccountMenuEntry(
        l10n.desktopAccountShowRecoveryPhrase,
        onSelected: () => manager.openInfo(account, start: AccountInfoStart.recoveryPhrase),
      ),
    if (items.contains(AccountMenuItem.multisigDetails))
      AccountMenuEntry(l10n.desktopAccountShowSigners, onSelected: () => manager.openInfo(account)),
  ];
  final last = [
    if (items.contains(AccountMenuItem.disconnect))
      AccountMenuEntry(
        switch (account) {
          MultisigAccount() => l10n.desktopAccountDisconnectMultisig,
          Account(accountType: AccountType.keystone) => l10n.desktopAccountDisconnectHardware,
          _ => l10n.desktopAccountDisconnectAccount,
        },
        isDestructive: true,
        onSelected: () => manager.openInfo(account, start: AccountInfoStart.disconnect),
      ),
  ];

  return [
    for (final (index, group) in [first, second, last].where((group) => group.isNotEmpty).indexed) ...[
      if (index > 0) null,
      ...group,
    ],
  ];
}

/// What a wallet heading's menu offers: Rename, and a software wallet's
/// recovery phrase. A Keystone wallet's phrase is not on this computer.
List<AccountMenuEntry> walletMenuEntries(AppLocalizations l10n, WalletGroup wallet, AccountManager manager) => [
  AccountMenuEntry(l10n.desktopAccountRename, onSelected: () => manager.startRenameWallet(wallet.walletIndex)),
  if (wallet.kind == WalletKind.software)
    AccountMenuEntry(
      l10n.desktopAccountShowRecoveryPhrase,
      onSelected: () => manager.openRecoveryPhrase(wallet.walletIndex),
    ),
];
