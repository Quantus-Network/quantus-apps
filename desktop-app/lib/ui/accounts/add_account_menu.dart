import 'dart:async';

import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// What the sidebar's Add Account menu offers: New Account, which with
/// several software [wallets] opens a submenu of them, so no screen has to
/// list every wallet just to add an account. A Cold Wallet is not among them.
List<ContextMenuItem?> addAccountMenuItems(
  AppLocalizations l10n,
  List<SoftwareWallet> wallets,
  AccountManager manager,
) {
  void create(SoftwareWallet wallet) => unawaited(manager.createAccount(wallet.walletIndex));

  return switch (wallets) {
    [] => const [],
    [final wallet] => [ContextMenuItem(l10n.desktopMenuNewAccount, onSelected: () => create(wallet))],
    _ => [
      ContextMenuItem.submenu(
        l10n.desktopMenuNewAccount,
        items: [for (final wallet in wallets) ContextMenuItem(wallet.name, onSelected: () => create(wallet))],
      ),
    ],
  };
}
