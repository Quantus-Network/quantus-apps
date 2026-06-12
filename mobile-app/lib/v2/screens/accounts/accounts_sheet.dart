import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/multisig_tag.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/add_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

Future<T?> showAccountsSheet<T>(BuildContext context) async {
  return BottomSheetContainer.show<T>(context, builder: (_) => const AccountsSheet());
}

class AccountsSheet extends ConsumerStatefulWidget {
  const AccountsSheet({super.key});

  @override
  ConsumerState<AccountsSheet> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsSheet> {
  List<Account> _sortedRegular(List<Account> accounts) {
    final sorted = [...accounts];
    sorted.sort((a, b) {
      final walletCmp = a.walletIndex.compareTo(b.walletIndex);
      if (walletCmp != 0) return walletCmp;
      return a.index.compareTo(b.index);
    });
    return sorted;
  }

  void _openAddAccountMenu() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const AddAccountMenuScreen()));
  }

  Future<void> _switchAccount(DisplayAccount display) async {
    await ref.read(activeAccountProvider.notifier).setActiveAccount(display);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openAccountMenu(Account account) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => AccountMenuScreen(initialAccount: account)));
  }

  void _openMultisigAccountMenu(MultisigAccount account) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => MultisigAccountMenuScreen(initialAccount: account)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final multisigAsync = ref.watch(multisigAccountsProvider);
    final activeDisplayAccountAsync = ref.watch(activeAccountProvider);

    final activeDisplayAccount = activeDisplayAccountAsync.value;
    final activeAccountId = activeDisplayAccount?.account.accountId;

    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 20;
    final sheetHeight = math.min(610.0, maxHeight);

    return BottomSheetContainer(
      title: l10n.accountsSheetTitle,
      height: sheetHeight,
      child: _buildContent(
        l10n: l10n,
        accountsAsync: accountsAsync,
        multisigAsync: multisigAsync,
        activeDisplayAccountAsync: activeDisplayAccountAsync,
        activeAccountId: activeAccountId,
      ),
    );
  }

  Widget _buildContent({
    required AppLocalizations l10n,
    required AsyncValue<List<Account>> accountsAsync,
    required AsyncValue<List<MultisigAccount>> multisigAsync,
    required AsyncValue<DisplayAccount?> activeDisplayAccountAsync,
    required String? activeAccountId,
  }) {
    if (accountsAsync.isLoading || activeDisplayAccountAsync.isLoading || multisigAsync.isLoading) {
      return const Center(child: Loader());
    }

    if (accountsAsync.hasError || multisigAsync.hasError) {
      return Center(
        child: Text(
          l10n.accountsSheetFailedLoadAccounts,
          style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary),
        ),
      );
    }

    if (activeDisplayAccountAsync.hasError) {
      return Center(
        child: Text(
          l10n.accountsSheetFailedLoadActiveAccount,
          style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary),
        ),
      );
    }

    final regulars = _sortedRegular(accountsAsync.value ?? []);
    final multisigs = multisigAsync.value ?? [];
    final items = <BaseAccount>[...regulars, ...multisigs];

    return _buildAccountsListView(l10n, items, activeAccountId);
  }

  Widget _buildAccountsListView(AppLocalizations l10n, List<BaseAccount> items, String? activeAccountId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    l10n.accountsSheetNoAccountsFound,
                    style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    final isActive = item.accountId == activeAccountId;
                    if (item is Account) return _buildRegularRow(l10n, item, isActive);
                    if (item is MultisigAccount) return _buildMultisigRow(l10n, item, isActive);
                    return const SizedBox.shrink();
                  },
                ),
        ),
        const SizedBox(height: 24),
        QuantusButton.simple(
          label: l10n.accountsSheetAddAccount,
          onTap: _openAddAccountMenu,
          variant: ButtonVariant.primary,
        ),
      ],
    );
  }

  Widget _buildRegularRow(AppLocalizations l10n, Account account, bool isActive) {
    final balanceAsync = ref.watch(balanceProviderFamily(account.accountId));
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final balanceText = balanceAsync.when(
      loading: () => l10n.commonLoading,
      error: (_, _) => l10n.accountsSheetBalanceUnavailable,
      data: (balance) => l10n.accountsSheetBalance(formattingService.formatBalance(balance), AppConstants.tokenSymbol),
    );

    return _AccountRowShell(
      isActive: isActive,
      onTap: () => _switchAccount(RegularAccount(account)),
      leading: AccountBadge.account(account: account, isActive: isActive),
      title: account.name,
      subtitle: balanceText,
      trailing: QuantusIconButton.circular(
        icon: Icons.edit_outlined,
        onTap: () => _openAccountMenu(account),
        size: IconButtonSize.medium,
      ),
    );
  }

  Widget _buildMultisigRow(AppLocalizations l10n, MultisigAccount account, bool isActive) {
    final balanceAsync = ref.watch(balanceProviderFamily(account.accountId));
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final balanceText = balanceAsync.when(
      loading: () => l10n.commonLoading,
      error: (_, _) => l10n.accountsSheetBalanceUnavailable,
      data: (balance) => l10n.accountsSheetBalance(formattingService.formatBalance(balance), AppConstants.tokenSymbol),
    );

    return _AccountRowShell(
      isActive: isActive,
      onTap: () => _switchAccount(MultisigDisplayAccount(account)),
      leading: AccountBadge(name: account.name, isActive: isActive),
      title: account.name,
      subtitle: balanceText,
      tag: MultisigTag(label: l10n.multisigTag),
      trailing: QuantusIconButton.circular(
        icon: Icons.edit_outlined,
        onTap: () => _openMultisigAccountMenu(account),
        size: IconButtonSize.medium,
      ),
    );
  }
}

class _AccountRowShell extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? tag;

  const _AccountRowShell({
    required this.isActive,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceDeep,
          borderRadius: BorderRadius.circular(14),
          border: isActive ? Border.all(color: colors.borderButton) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: context.themeText.paragraph!.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: colors.textPrimary,
                                  height: 1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tag != null) ...[const SizedBox(width: 8), tag!],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: context.themeText.smallParagraph!.copyWith(
                            fontSize: 14,
                            color: colors.textTertiary,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
