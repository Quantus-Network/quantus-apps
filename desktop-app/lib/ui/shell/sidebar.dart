import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/account_balance_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// Its header, then the accounts grouped by wallet, with Mining Rewards beneath
/// them and Add Account at the foot. Choosing an account makes it the active account.
///
/// Wallets keep one order (software wallets by index, then Keystone) whichever
/// account is active, so a row never moves when it is clicked.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  static const double width = 260;

  /// The size of the icon before a row that is not an account.
  static const double _iconSize = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final selection = ref.watch(sidebarSelectionProvider);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border(right: BorderSide(color: colors.borderHairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SidebarHeader(),
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
            child: SidebarRow(
              title: l10n.accountsSheetAddAccount,
              isSecondary: true,
              leading: const QuantusIcon(QuantusIcons.plus, size: _iconSize),
              onTap: () => ref.read(shellSheetProvider.notifier).open(ShellSheet.addAccount),
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
        for (final account in wallet.accounts) row(RegularAccount(account)),
        if (wallet.encryptedAccount case final encrypted?) row(RegularAccount(encrypted)),
        for (final multisig in wallet.multisigs) row(MultisigDisplayAccount(multisig)),
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
    final custom = ref.watch(walletNameProvider(wallet.walletIndex));
    final name = custom != null && custom.isNotEmpty
        ? custom
        : switch (wallet.kind) {
            WalletKind.software => l10n.accountsSheetWallet(wallet.number),
            WalletKind.keystone => l10n.accountsSheetKeystoneWallet(wallet.number),
          };

    // Drawn in capitals, which is a look and not the name: a screen reader
    // gets the name as it is written.
    return Semantics(
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
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.display, required this.isSelected});

  final DisplayAccount display;
  final bool isSelected;

  static const double _badgeSize = 28;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = display.account;

    return SidebarRow(
      title: account.name,
      isSelected: isSelected,
      leading: DesktopAccountBadge(account: account, size: _badgeSize),
      subtitle: AccountBalanceText(
        account: account,
        style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted),
      ),
      trailing: display is MultisigDisplayAccount ? QuantusBadge(label: ref.watch(l10nProvider).multisigTag) : null,
      onTap: () async {
        await ref.read(activeAccountProvider.notifier).setActiveAccount(display);
        if (!context.mounted) return;
        ref.read(sidebarSelectionProvider.notifier).select(SidebarSelection.account);
      },
    );
  }
}
