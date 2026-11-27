import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// What the sidebar's Add Account menu offers: New Account, which with
/// several software [wallets] opens a submenu of them, so no screen has to
/// list every wallet just to add an account (a Cold Wallet is not among
/// them), then, after a separator, New Wallet ([onNewWallet]) and Import
/// Wallet…, with Connect Cold Wallet… when [offersColdWallets], then, when
/// [offersMultisigs], Create Multisig…, disabled unless [canCreateMultisig],
/// and Manage Multisigs… after another.
List<ContextMenuItem?> addAccountMenuItems(
  AppLocalizations l10n,
  List<SoftwareWallet> wallets,
  AccountManager manager, {
  required VoidCallback onNewWallet,
  required bool offersColdWallets,
  required bool offersMultisigs,
  required bool canCreateMultisig,
}) {
  void create(SoftwareWallet wallet) => unawaited(manager.createAccount(wallet.walletIndex));

  return [
    ...switch (wallets) {
      [] => const <ContextMenuItem>[],
      [final wallet] => [ContextMenuItem(l10n.desktopMenuNewAccount, onSelected: () => create(wallet))],
      _ => [
        ContextMenuItem.submenu(
          l10n.desktopMenuNewAccount,
          items: [for (final wallet in wallets) ContextMenuItem(wallet.name, onSelected: () => create(wallet))],
        ),
      ],
    },
    if (wallets.isNotEmpty) null,
    ContextMenuItem(l10n.desktopMenuNewWallet, onSelected: onNewWallet),
    ContextMenuItem(l10n.desktopMenuImportWallet, onSelected: () => unawaited(manager.openImportWallet())),
    if (offersColdWallets) connectColdWalletMenuItem(l10n, manager),
    if (offersMultisigs) ...[null, ...multisigMenuItems(l10n, manager, canCreateMultisig: canCreateMultisig)],
  ];
}

/// Connect Cold Wallet…, as the Add Account menu and a cold wallet's heading
/// offer it.
ContextMenuItem connectColdWalletMenuItem(AppLocalizations l10n, AccountManager manager) =>
    ContextMenuItem(l10n.desktopMenuConnectColdWallet, onSelected: () => unawaited(manager.openConnectColdWallet()));

/// Create Multisig…, disabled unless [canCreateMultisig], and Manage
/// Multisigs…, as the Add Account menu and the multisigs' heading offer them.
List<ContextMenuItem> multisigMenuItems(
  AppLocalizations l10n,
  AccountManager manager, {
  required bool canCreateMultisig,
}) => [
  if (canCreateMultisig)
    ContextMenuItem(l10n.desktopMenuCreateMultisig, onSelected: () => unawaited(manager.openCreateMultisig()))
  else
    ContextMenuItem.disabled(l10n.desktopMenuCreateMultisig),
  ContextMenuItem(l10n.desktopMenuManageMultisigs, onSelected: () => unawaited(manager.openManageMultisigs())),
];
