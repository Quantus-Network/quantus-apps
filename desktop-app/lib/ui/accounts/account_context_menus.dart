import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/sidebar_order_provider.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_menu_entries.dart';
import 'package:quantus_desktop_wallet/ui/accounts/add_account_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
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
/// wallets are offered; then, on every one, Move Up and Move Down
/// ([moveGroupMenuItems]).
class WalletContextMenu extends ConsumerWidget {
  const WalletContextMenu({super.key, required this.wallet, required this.child});

  final WalletGroup wallet;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuRegion(
      // Read as the menu opens, so it is what holds then.
      items: () {
        final l10n = ref.read(l10nProvider);
        final manager = ref.read(accountManagerProvider);
        final own = switch (wallet.kind) {
          WalletKind.software => _items(walletMenuEntries(l10n, wallet, manager)),
          WalletKind.keystone => [
            if (ref.read(remoteConfigProvider).enableKeystoneHardwareWallet) connectColdWalletMenuItem(l10n, manager),
          ],
        };
        return [
          ...own,
          if (own.isNotEmpty) null,
          ...moveGroupMenuItems(l10n, ref.read(sidebarGroupMoverProvider), SidebarWallet.keyOf(wallet.walletIndex)),
        ];
      },
      child: child,
    );
  }
}

/// The context menu of the multisigs' heading: Create Multisig… and Manage
/// Multisigs…, as Add Account offers them, where multisigs are offered; then
/// Move Up and Move Down ([moveGroupMenuItems]).
class MultisigsContextMenu extends ConsumerWidget {
  const MultisigsContextMenu({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuRegion(
      // Read as the menu opens, so it is what holds then.
      items: () {
        final l10n = ref.read(l10nProvider);
        return [
          if (ref.read(remoteConfigProvider).enableMultisig) ...[
            ...multisigMenuItems(
              l10n,
              ref.read(accountManagerProvider),
              canCreateMultisig: ref.read(multisigCreatorProvider) != null,
            ),
            null,
          ],
          ...moveGroupMenuItems(l10n, ref.read(sidebarGroupMoverProvider), SidebarMultisigs.key),
        ];
      },
      child: child,
    );
  }
}

/// Move Up and Move Down for the sidebar's group kept as [key], each shown
/// dimmed where the group is already at that end.
List<ContextMenuItem> moveGroupMenuItems(AppLocalizations l10n, SidebarGroupMover mover, String key) => [
  for (final (label, by) in [(l10n.desktopSidebarMoveUp, -1), (l10n.desktopSidebarMoveDown, 1)])
    mover.canMoveBy(key, by)
        ? ContextMenuItem(label, onSelected: () => mover.moveBy(key, by))
        : ContextMenuItem.disabled(label),
];

/// [entries] as context menu items.
List<ContextMenuItem?> _items(List<AccountMenuEntry?> entries) => [
  for (final entry in entries)
    if (entry == null)
      null
    else
      ContextMenuItem(entry.label, onSelected: entry.onSelected, isDestructive: entry.isDestructive),
];
