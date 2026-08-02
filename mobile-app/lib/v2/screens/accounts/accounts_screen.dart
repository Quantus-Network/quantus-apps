import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/components/multisig_tag.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/wallet_name_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/add_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

Future<T?> openAccountsScreen<T>(BuildContext context) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      settings: const RouteSettings(name: accountsScreenRouteName),
      builder: (_) => const AccountsScreen(),
    ),
  );
}

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final GlobalKey _scrollTargetKey = GlobalKey();
  bool _scrolledToTarget = false;
  String? _highlightAccountId;
  final Set<int> _expandedWallets = {};
  bool _autoExpandedActive = false;

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
      quantusPrint('[AccountsScreen] ensure encrypted accounts failed: $e\n$st');
    }
  }

  /// Reacts to an add/import flow popping back to this already-open screen:
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
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const AddAccountMenuScreen()));
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

  void _openWalletNameEditor(int walletIndex) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => WalletNameScreen(walletIndex: walletIndex)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OpenAccountsIntent?>(openAccountsIntentProvider, (_, next) => _applyOpenAccountsIntent(next));

    final l10n = ref.watch(l10nProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final multisigAsync = ref.watch(multisigAccountsProvider);
    final activeDisplayAccountAsync = ref.watch(activeAccountProvider);

    final activeAccountId = activeDisplayAccountAsync.value?.account.accountId;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.accountsSheetTitle),
      mainContent: _buildContent(
        l10n: l10n,
        accountsAsync: accountsAsync,
        multisigAsync: multisigAsync,
        activeDisplayAccountAsync: activeDisplayAccountAsync,
        activeAccountId: activeAccountId,
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.accountsSheetAddAccount,
          onTap: _openAddAccountMenu,
          variant: ButtonVariant.primary,
          icon: Icon(Icons.add, size: 16, color: context.colors.background),
          iconPlacement: IconPlacement.leading,
        ),
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

    final grouping = groupWallets(accounts: accountsAsync.value ?? [], multisigs: multisigAsync.value ?? []);

    if (grouping.wallets.isEmpty && grouping.standaloneMultisigs.isEmpty) {
      return Center(
        child: Text(
          l10n.accountsSheetNoAccountsFound,
          style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary),
        ),
      );
    }

    return _buildWalletsListView(l10n, grouping, activeAccountId);
  }

  bool _containsAccount(WalletGroup group, String? accountId) {
    if (accountId == null) return false;
    return group.accounts.any((a) => a.accountId == accountId) ||
        group.encryptedAccount?.accountId == accountId ||
        group.multisigs.any((m) => m.accountId == accountId);
  }

  Widget _buildWalletsListView(AppLocalizations l10n, WalletsGrouping grouping, String? activeAccountId) {
    final scrollTargetId = _highlightAccountId ?? activeAccountId;

    // First open: reveal where the user currently is when the active account
    // lives in a secondary wallet. A pending highlight (new account from an
    // add/import flow) must also expand its wallet to be scrolled to.
    if (!_autoExpandedActive) {
      _autoExpandedActive = true;
      final activeGroup = grouping.wallets.skip(1).firstWhereOrNull((g) => _containsAccount(g, activeAccountId));
      if (activeGroup != null) _expandedWallets.add(activeGroup.walletIndex);
    }
    if (!_scrolledToTarget && scrollTargetId != null) {
      final targetGroup = grouping.wallets.skip(1).firstWhereOrNull((g) => _containsAccount(g, scrollTargetId));
      if (targetGroup != null) _expandedWallets.add(targetGroup.walletIndex);
    }
    _maybeScrollToTarget();

    final mainWallet = grouping.wallets.first;
    final otherWallets = grouping.wallets.skip(1).toList();

    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildWalletHeader(l10n, mainWallet, activeAccountId),
        const SizedBox(height: 14),
        ..._withGaps(_walletRows(l10n, mainWallet, activeAccountId, scrollTargetId), 14),
        if (otherWallets.isNotEmpty || grouping.standaloneMultisigs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: context.colors.separator, height: 1),
          const SizedBox(height: 16),
        ],
        ..._withGaps([
          for (final wallet in otherWallets) _buildCollapsibleWallet(l10n, wallet, activeAccountId, scrollTargetId),
          for (final multisig in grouping.standaloneMultisigs)
            _buildMultisigRow(l10n, multisig, multisig.accountId == activeAccountId, scrollTargetId),
        ], 14),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Widget> _withGaps(List<Widget> children, double gap) => [
    for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
  ];

  String _walletDisplayName(AppLocalizations l10n, WalletGroup wallet) {
    final custom = ref.watch(walletNameProvider(wallet.walletIndex));
    if (custom != null && custom.isNotEmpty) return custom;
    return switch (wallet.kind) {
      WalletKind.software => l10n.accountsSheetWallet(wallet.number),
      WalletKind.keystone => l10n.accountsSheetKeystoneWallet(wallet.number),
    };
  }

  List<Widget> _walletRows(AppLocalizations l10n, WalletGroup wallet, String? activeAccountId, String? scrollTargetId) {
    return [
      for (final account in wallet.accounts) _buildRegularRow(l10n, account, activeAccountId, scrollTargetId),
      if (wallet.encryptedAccount != null)
        _buildEncryptedRow(l10n, wallet.encryptedAccount!, activeAccountId, scrollTargetId),
      for (final multisig in wallet.multisigs)
        _buildMultisigRow(l10n, multisig, multisig.accountId == activeAccountId, scrollTargetId),
    ];
  }

  Widget _buildWalletHeader(AppLocalizations l10n, WalletGroup wallet, String? activeAccountId) {
    return Row(
      children: [
        Flexible(
          child: Text(
            _walletDisplayName(l10n, wallet),
            style: context.themeText.paragraph?.copyWith(height: 1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        QuantusIconButton.circular(
          icon: Icons.edit_outlined,
          onTap: () => _openWalletNameEditor(wallet.walletIndex),
          size: IconButtonSize.small,
        ),
        const Spacer(),
        if (_containsAccount(wallet, activeAccountId)) _ActiveWalletTag(label: l10n.accountsScreenActiveWallet),
      ],
    );
  }

  Widget _buildCollapsibleWallet(
    AppLocalizations l10n,
    WalletGroup wallet,
    String? activeAccountId,
    String? scrollTargetId,
  ) {
    final colors = context.colors;
    final expanded = _expandedWallets.contains(wallet.walletIndex);
    final displayName = _walletDisplayName(l10n, wallet);

    return Container(
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              expanded ? _expandedWallets.remove(wallet.walletIndex) : _expandedWallets.add(wallet.walletIndex);
            }),
            behavior: HitTestBehavior.opaque,
            child: expanded
                ? _buildExpandedWalletHeader(l10n, wallet, displayName, activeAccountId)
                : _buildCollapsedWalletHeader(l10n, wallet, displayName),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Divider(color: colors.separator, height: 1),
                      ),
                      const SizedBox(height: 8),
                      ..._walletRows(l10n, wallet, activeAccountId, scrollTargetId),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedWalletHeader(AppLocalizations l10n, WalletGroup wallet, String displayName) {
    final colors = context.colors;
    return Row(
      children: [
        AccountBadge(name: displayName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: context.themeText.paragraph!.copyWith(fontSize: 18, height: 1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _walletBalanceText(l10n, wallet),
                style: context.themeText.smallParagraph!.copyWith(fontSize: 14, color: colors.textTertiary, height: 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.accountsScreenAccountCount(wallet.accountCount),
          style: context.themeText.smallParagraph?.copyWith(fontSize: 14, color: colors.textSubtle, height: 1),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down, size: 20, color: colors.textMuted),
      ],
    );
  }

  Widget _buildExpandedWalletHeader(
    AppLocalizations l10n,
    WalletGroup wallet,
    String displayName,
    String? activeAccountId,
  ) {
    return Row(
      children: [
        Flexible(
          child: Text(
            displayName,
            style: context.themeText.paragraph?.copyWith(height: 1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        QuantusIconButton.circular(
          icon: Icons.edit_outlined,
          onTap: () => _openWalletNameEditor(wallet.walletIndex),
          size: IconButtonSize.small,
        ),
        const Spacer(),
        if (_containsAccount(wallet, activeAccountId)) ...[
          _ActiveWalletTag(label: l10n.accountsScreenActiveWallet),
          const SizedBox(width: 8),
        ],
        Icon(Icons.keyboard_arrow_up, size: 20, color: context.colors.textMuted),
      ],
    );
  }

  String _walletBalanceText(AppLocalizations l10n, WalletGroup wallet) {
    final balances = <AsyncValue<BigInt>>[
      for (final account in wallet.accounts) ref.watch(balanceProviderFamily(account.accountId)),
      if (wallet.encryptedAccount != null) ref.watch(encryptedBalanceProvider(wallet.walletIndex)),
      for (final multisig in wallet.multisigs) ref.watch(balanceProviderFamily(multisig.accountId)),
    ];
    if (balances.any((b) => b.isLoading)) return l10n.commonLoading;
    if (balances.any((b) => b.hasError)) return l10n.accountsSheetBalanceUnavailable;
    final total = balances.fold(BigInt.zero, (sum, b) => sum + (b.value ?? BigInt.zero));
    final formattingService = ref.watch(numberFormattingServiceProvider);
    return l10n.accountsSheetBalance(formattingService.formatBalance(total), AppConstants.tokenSymbol);
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

  Widget _buildRegularRow(AppLocalizations l10n, Account account, String? activeAccountId, String? scrollTargetId) {
    final isActive = account.accountId == activeAccountId;
    return _AccountRowShell(
      key: account.accountId == scrollTargetId ? _scrollTargetKey : null,
      isActive: isActive,
      isHighlighted: account.accountId == _highlightAccountId,
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

  Widget _buildEncryptedRow(AppLocalizations l10n, Account account, String? activeAccountId, String? scrollTargetId) {
    return _AccountRowShell(
      key: account.accountId == scrollTargetId ? _scrollTargetKey : null,
      isActive: account.accountId == activeAccountId,
      isHighlighted: account.accountId == _highlightAccountId,
      onTap: () => _switchAccount(RegularAccount(account)),
      leading: const EncryptedLockBadge(),
      title: account.name,
      subtitle: _balanceText(l10n, account),
    );
  }

  Widget _buildMultisigRow(AppLocalizations l10n, MultisigAccount account, bool isActive, String? scrollTargetId) {
    return _AccountRowShell(
      key: account.accountId == scrollTargetId ? _scrollTargetKey : null,
      isActive: isActive,
      isHighlighted: account.accountId == _highlightAccountId,
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

class _ActiveWalletTag extends StatelessWidget {
  final String label;

  const _ActiveWalletTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.accentOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.useOpacity(0.1)),
        color: accent.useOpacity(0.1),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.themeText.detail?.copyWith(
          color: accent,
          fontSize: 11,
          letterSpacing: 0.88,
          height: 1.2,
          fontFamily: AppTextTheme.fontFamilySecondary,
        ),
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
