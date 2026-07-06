import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/multisig_tag.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/add_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

Future<T?> showAccountsSheet<T>(BuildContext context) async {
  return BottomSheetContainer.show<T>(
    context,
    routeSettings: const RouteSettings(name: accountsSheetRouteName),
    builder: (_) => const AccountsSheet(),
  );
}

class AccountsSheet extends ConsumerStatefulWidget {
  const AccountsSheet({super.key});

  @override
  ConsumerState<AccountsSheet> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsSheet> {
  final GlobalKey _scrollTargetKey = GlobalKey();
  bool _scrolledToTarget = false;
  String? _highlightAccountId;

  @override
  void initState() {
    super.initState();
    _ensureEncryptedAccounts();
  }

  /// Backfills the per-wallet encrypted (wormhole) account for every software
  /// wallet so it shows alongside transparent accounts. Gated by the feature
  /// flag; persists once, then no-ops on subsequent opens.
  Future<void> _ensureEncryptedAccounts() async {
    try {
      final created = await ensureEncryptedAccounts(ref);
      if (created && mounted) ref.invalidate(accountsProvider);
    } catch (e, st) {
      quantusDebugPrint('[AccountsSheet] ensure encrypted accounts failed: $e\n$st');
    }
  }

  /// Reacts to an add/import flow popping back to this already-open sheet:
  /// highlight the new account and re-run the scroll-into-view.
  void _applyOpenAccountsIntent(OpenAccountsIntent? intent) {
    if (intent == null) return;
    ref.read(openAccountsIntentProvider.notifier).state = null;
    setState(() {
      _highlightAccountId = intent.highlightAccountId;
      _scrolledToTarget = false;
    });
  }

  void _maybeScrollToTarget() {
    if (_scrolledToTarget) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _scrollTargetKey.currentContext;
      if (ctx == null) return;
      _scrolledToTarget = true;
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut, alignment: 0.5);
    });
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
    ref.listen<OpenAccountsIntent?>(openAccountsIntentProvider, (_, next) => _applyOpenAccountsIntent(next));

    final l10n = ref.watch(l10nProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final multisigAsync = ref.watch(multisigAccountsProvider);
    final activeDisplayAccountAsync = ref.watch(activeAccountProvider);

    final activeAccountId = activeDisplayAccountAsync.value?.account.accountId;

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

    final grouping = groupAccounts(accounts: accountsAsync.value ?? [], multisigs: multisigAsync.value ?? []);

    return _buildAccountsListView(l10n, grouping, activeAccountId);
  }

  Widget _buildAccountsListView(AppLocalizations l10n, AccountsGrouping grouping, String? activeAccountId) {
    final scrollTargetId = _highlightAccountId ?? activeAccountId;
    _maybeScrollToTarget();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: grouping.items.isEmpty
              ? Center(
                  child: Text(
                    l10n.accountsSheetNoAccountsFound,
                    style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary),
                  ),
                )
              : ListView(children: _buildItemWidgets(l10n, grouping.items, activeAccountId, scrollTargetId)),
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

  List<Widget> _buildItemWidgets(
    AppLocalizations l10n,
    List<AccountListItem> items,
    String? activeAccountId,
    String? scrollTargetId,
  ) {
    final widgets = <Widget>[];
    AccountListItem? prev;
    for (final item in items) {
      final gap = _gapBefore(prev, item);
      if (gap > 0) widgets.add(SizedBox(height: gap));
      widgets.add(switch (item) {
        WalletHeaderItem() => _buildWalletHeader(l10n, item),
        SegmentHeaderItem() => _buildSegmentHeader(l10n, item),
        AccountRowItem() => _buildRow(l10n, item.account, activeAccountId, scrollTargetId),
      });
      prev = item;
    }
    return widgets;
  }

  double _gapBefore(AccountListItem? prev, AccountListItem item) {
    if (prev == null) return 0;
    if (item is WalletHeaderItem) return 24;
    if (item is SegmentHeaderItem) return 18;
    return prev is AccountRowItem ? 14 : 12;
  }

  Widget _buildWalletHeader(AppLocalizations l10n, WalletHeaderItem item) {
    final title = switch (item.kind) {
      WalletKind.software => l10n.accountsSheetWallet(item.number),
      WalletKind.keystone => l10n.accountsSheetKeystoneWallet(item.number),
    };
    return Text(
      title,
      style: context.themeText.smallParagraph?.copyWith(
        color: context.colors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSegmentHeader(AppLocalizations l10n, SegmentHeaderItem item) {
    final title = switch (item.segment) {
      AccountSegment.transparent => l10n.accountsSheetSubheaderTransparent,
      AccountSegment.encrypted => l10n.accountsSheetSubheaderEncrypted,
      AccountSegment.keystone => l10n.accountsSheetSubheaderKeystone,
      AccountSegment.multisig => l10n.accountsSheetSubheaderMultisig,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: context.themeText.detail?.copyWith(color: context.colors.textTertiary)),
    );
  }

  Widget _buildRow(AppLocalizations l10n, BaseAccount account, String? activeAccountId, String? scrollTargetId) {
    final isActive = account.accountId == activeAccountId;
    final isHighlighted = account.accountId == _highlightAccountId;
    final key = account.accountId == scrollTargetId ? _scrollTargetKey : null;

    if (account is MultisigAccount) return _buildMultisigRow(l10n, account, isActive, isHighlighted, key);
    if (account is Account && account.accountType == AccountType.encrypted) {
      return _buildEncryptedRow(l10n, account, isActive, isHighlighted, key);
    }
    if (account is Account) return _buildRegularRow(l10n, account, isActive, isHighlighted, key);
    return const SizedBox.shrink();
  }

  String _balanceText(AppLocalizations l10n, BaseAccount account) {
    final balanceAsync = isEncryptedAccount(account)
        ? ref.watch(encryptedBalanceProvider((account as Account).walletIndex))
        : ref.watch(balanceProviderFamily(account.accountId));
    final formattingService = ref.watch(numberFormattingServiceProvider);
    return balanceAsync.when(
      loading: () => l10n.commonLoading,
      error: (_, _) => l10n.accountsSheetBalanceUnavailable,
      data: (balance) => l10n.accountsSheetBalance(formattingService.formatBalance(balance), AppConstants.tokenSymbol),
    );
  }

  Widget _buildRegularRow(AppLocalizations l10n, Account account, bool isActive, bool isHighlighted, Key? key) {
    return _AccountRowShell(
      key: key,
      isActive: isActive,
      isHighlighted: isHighlighted,
      onTap: () => _switchAccount(RegularAccount(account)),
      leading: AccountBadge.account(account: account, isActive: isActive),
      title: account.name,
      subtitle: _balanceText(l10n, account),
      trailing: QuantusIconButton.circular(
        icon: Icons.edit_outlined,
        onTap: () => _openAccountMenu(account),
        size: IconButtonSize.medium,
      ),
    );
  }

  Widget _buildEncryptedRow(AppLocalizations l10n, Account account, bool isActive, bool isHighlighted, Key? key) {
    return _AccountRowShell(
      key: key,
      isActive: isActive,
      isHighlighted: isHighlighted,
      onTap: () => _switchAccount(RegularAccount(account)),
      leading: AccountBadge.icon(icon: Icons.lock_outline, isActive: isActive),
      subtitle: _balanceText(l10n, account),
    );
  }

  Widget _buildMultisigRow(
    AppLocalizations l10n,
    MultisigAccount account,
    bool isActive,
    bool isHighlighted,
    Key? key,
  ) {
    return _AccountRowShell(
      key: key,
      isActive: isActive,
      isHighlighted: isHighlighted,
      onTap: () => _switchAccount(MultisigDisplayAccount(account)),
      leading: AccountBadge(name: account.name, isActive: isActive),
      title: account.name,
      subtitle: _balanceText(l10n, account),
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
  final bool isHighlighted;
  final VoidCallback onTap;
  final Widget leading;
  final String? title;
  final String subtitle;
  final Widget? trailing;
  final Widget? tag;

  const _AccountRowShell({
    super.key,
    required this.isActive,
    required this.onTap,
    required this.leading,
    required this.subtitle,
    this.isHighlighted = false,
    this.title,
    this.trailing,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = isHighlighted
        ? Border.all(color: colors.accentOrange, width: 2)
        : isActive
        ? Border.all(color: colors.borderButton)
        : null;
    final hasTitle = title != null && title!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14), border: border),
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
                        if (hasTitle) ...[
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title!,
                                  style: context.themeText.paragraph!.copyWith(fontSize: 18, height: 1),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tag != null) ...[const SizedBox(width: 8), tag!],
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
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
