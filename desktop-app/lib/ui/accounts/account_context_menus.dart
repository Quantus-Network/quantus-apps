import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_menu_entries.dart';
import 'package:quantus_desktop_wallet/ui/accounts/add_account_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// The context menu of an account's row: what [account]'s menu offers
/// ([accountMenuEntries]), acting on it whether or not it is the active one.
class AccountContextMenu extends ConsumerWidget {
  const AccountContextMenu({super.key, required this.account, required this.child});

  final BaseAccount account;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuRegion(
      // Read as the menu opens, so it is what holds then.
      items: () => _items(
        accountMenuEntries(
          ref.read(l10nProvider),
          account,
          ref.read(accountsProvider).requireValue,
          ref.read(accountManagerProvider),
        ),
      ),
      child: child,
    );
  }
}

/// The context menu of a wallet's heading: a software wallet's entries
/// ([walletMenuEntries]); on a cold wallet's, Connect Cold Wallet… where cold
/// wallets are offered. [child] alone where there is nothing to offer.
class WalletContextMenu extends ConsumerWidget {
  const WalletContextMenu({super.key, required this.wallet, required this.child});

  final WalletGroup wallet;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final manager = ref.watch(accountManagerProvider);
    final items = switch (wallet.kind) {
      WalletKind.software => _items(walletMenuEntries(l10n, wallet, manager)),
      WalletKind.keystone => [
        if (ref.watch(remoteConfigProvider).enableKeystoneHardwareWallet) connectColdWalletMenuItem(l10n, manager),
      ],
    };
    if (items.isEmpty) return child;
    return ContextMenuRegion(items: () => items, child: child);
  }
}

/// The context menu of the multisigs' heading: Create Multisig… and Manage
/// Multisigs…, as Add Account offers them; [child] alone where multisigs are
/// not offered.
class MultisigsContextMenu extends ConsumerWidget {
  const MultisigsContextMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(remoteConfigProvider).enableMultisig) return child;
    return ContextMenuRegion(
      // Read as the menu opens, so it is what holds then.
      items: () => multisigMenuItems(
        ref.read(l10nProvider),
        ref.read(accountManagerProvider),
        canCreateMultisig: ref.read(multisigCreatorProvider) != null,
      ),
      child: child,
    );
  }
}

/// [entries] as context menu items.
List<ContextMenuItem?> _items(List<AccountMenuEntry?> entries) => [
  for (final entry in entries)
    if (entry == null)
      null
    else
      ContextMenuItem(entry.label, onSelected: entry.onSelected, isDestructive: entry.isDestructive),
];
