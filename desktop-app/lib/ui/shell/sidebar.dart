import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_context_menus.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_note_text.dart';
import 'package:quantus_desktop_wallet/ui/components/account_balance_text.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_desktop_wallet/utils/wallet_names.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// The Accounts panel: the accounts grouped by wallet, with Mining Rewards
/// beneath them, and Settings and Add Account at the foot. Choosing an account
/// makes it the active account. The shell sets its width
/// ([sidebarWidthProvider]).
///
/// Wallets keep one order (software wallets by index, then Keystone) whichever
/// account is active, so a row never moves when it is clicked.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  /// The size of the icon before a row that is not an account.
  static const double _iconSize = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final selection = ref.watch(sidebarSelectionProvider);

    return Panel(
      title: l10n.accountsSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                ..._accounts(context, ref, l10n, selection),
                const SizedBox(height: 10),
                const MenuDivider(),
                const SizedBox(height: 6),
                SidebarRow(
                  title: l10n.settingsMiningRewards,
                  isSecondary: true,
                  leading: Icon(Icons.hardware_outlined, size: _iconSize, color: colors.textMuted),
                  isSelected: selection == SidebarSelection.miningRewards,
                  onTap: () => ref.read(sidebarSelectionProvider.notifier).select(SidebarSelection.miningRewards),
                ),
              ],
            ),
          ),
          const MenuDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                SidebarRow(
                  title: l10n.settingsTitle,
                  isSecondary: true,
                  leading: Icon(CupertinoIcons.gear, size: _iconSize, color: colors.textMuted),
                  onTap: () => ref.read(shellSheetProvider.notifier).open(ShellSheet.settings),
                ),
                SidebarRow(
                  title: l10n.accountsSheetAddAccount,
                  isSecondary: true,
                  leading: const QuantusIcon(QuantusIcons.plus, size: _iconSize),
                  onTap: () => ref.read(shellSheetProvider.notifier).open(ShellSheet.addAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _accounts(BuildContext context, WidgetRef ref, AppLocalizations l10n, SidebarSelection selection) {
    final accounts = ref.watch(accountsProvider);
    final multisigs = ref.watch(multisigAccountsProvider);
    final active = ref.watch(activeAccountProvider);

    if (accounts.isLoading || multisigs.isLoading || active.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Loader()),
        ),
      ];
    }
    if (accounts.hasError || multisigs.hasError) return [_message(context, l10n.accountsSheetFailedLoadAccounts)];
    if (active.hasError) return [_message(context, l10n.accountsSheetFailedLoadActiveAccount)];

    final grouping = groupWallets(accounts: accounts.value ?? [], multisigs: multisigs.value ?? []);
    if (grouping.wallets.isEmpty && grouping.standaloneMultisigs.isEmpty) {
      return [_message(context, l10n.accountsSheetNoAccountsFound)];
    }

    final selectedAccountId = selection == SidebarSelection.account ? active.value?.account.accountId : null;
    Widget row(DisplayAccount display) =>
        _AccountRow(display: display, isSelected: display.account.accountId == selectedAccountId);

    return [
      for (final wallet in grouping.wallets) ...[
        _WalletHeader(wallet: wallet),
        for (final account in walletAccountsInOrder(wallet)) row(account),
      ],
      if (grouping.standaloneMultisigs.isNotEmpty) ...[
        if (grouping.wallets.isNotEmpty) ...[
          const SizedBox(height: 12),
          const MenuDivider(),
          const SizedBox(height: 12),
        ],
        for (final multisig in grouping.standaloneMultisigs) row(MultisigDisplayAccount(multisig)),
      ],
    ];
  }

  Widget _message(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }
}

class _WalletHeader extends ConsumerWidget {
  const _WalletHeader({required this.wallet});

  final WalletGroup wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final name = walletDisplayName(l10n, wallet, ref.watch(walletNameProvider(wallet.walletIndex)));

    // Drawn in capitals, which is a look and not the name: a screen reader
    // gets the name as it is written.
    final heading = Semantics(
      label: name,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
        child: Text(
          name.toUpperCase(),
          style: context.themeTextV3.caption.copyWith(
            color: context.colorsV3.textMuted2,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    return WalletContextMenu(wallet: wallet, child: heading);
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.display, required this.isSelected});

  final DisplayAccount display;
  final bool isSelected;

  static const double _badgeSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = display.account;
    // A note about the account ("Address copied") shows in its balance's place.
    final note = ref.watch(accountNoteProvider);

    final row = SidebarRow(
      title: account.name,
      isSelected: isSelected,
      leading: DesktopAccountBadge(account: account, size: _badgeSize),
      subtitle: note != null && note.accountId == account.accountId
          ? AccountNoteText(note: note)
          : AccountBalanceText(
              account: account,
              style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted),
            ),
      trailing: display is MultisigDisplayAccount ? QuantusBadge(label: ref.watch(l10nProvider).multisigTag) : null,
      // A Control-click opens the menu instead.
      onTap: () {
        if (ContextMenuRegion.isControlClick) return;
        ref.read(sidebarSelectionProvider.notifier).showAccount(display);
      },
    );
    return AccountContextMenu(account: account, child: row);
  }
}
