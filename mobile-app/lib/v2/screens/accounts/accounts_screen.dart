import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/multisig_tag.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_account_menu_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/wallet_name_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/add_account_menu_screen.dart';

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
          icon: QuantusIcon(QuantusIcons.plus, size: 16, color: context.colorsV3.textVoid),
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
      return _centeredMessage(l10n.accountsSheetFailedLoadAccounts);
    }

    if (activeDisplayAccountAsync.hasError) {
      return _centeredMessage(l10n.accountsSheetFailedLoadActiveAccount);
    }

    final grouping = groupWallets(
      accounts: accountsAsync.value ?? [],
      multisigs: multisigAsync.value ?? [],
      activeAccountId: activeAccountId,
    );

    if (grouping.wallets.isEmpty && grouping.standaloneMultisigs.isEmpty) {
      return _centeredMessage(l10n.accountsSheetNoAccountsFound);
    }

    return _buildWalletsListView(l10n, grouping, activeAccountId);
  }

  Widget _centeredMessage(String message) {
    return Center(
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }

  bool _containsAccount(WalletGroup group, String? accountId) => accountId != null && group.contains(accountId);

  Widget _buildWalletsListView(AppLocalizations l10n, WalletsGrouping grouping, String? activeAccountId) {
    final scrollTargetId = _highlightAccountId ?? activeAccountId;

    // A pending highlight (new account from an add/import flow) must expand
    // its wallet to be scrolled to.
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
          const MenuDivider(),
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
        Expanded(child: _buildWalletNameAndEdit(l10n, wallet)),
        if (_containsAccount(wallet, activeAccountId)) _ActiveWalletTag(label: l10n.accountsScreenActiveWallet),
      ],
    );
  }

  Widget _buildWalletNameAndEdit(AppLocalizations l10n, WalletGroup wallet) {
    return Row(
      children: [
        Flexible(
          child: Text(
            _walletDisplayName(l10n, wallet),
            style: context.themeTextV3.headingRow.copyWith(color: context.colorsV3.textContent),
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
      ],
    );
  }

  Widget _buildCollapsibleWallet(
    AppLocalizations l10n,
    WalletGroup wallet,
    String? activeAccountId,
    String? scrollTargetId,
  ) {
    final colors = context.colorsV3;
    final expanded = _expandedWallets.contains(wallet.walletIndex);
    final displayName = _walletDisplayName(l10n, wallet);

    return Container(
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              expanded ? _expandedWallets.remove(wallet.walletIndex) : _expandedWallets.add(wallet.walletIndex);
            }),
            behavior: HitTestBehavior.opaque,
            child: expanded
                ? _buildExpandedWalletHeader(l10n, wallet, activeAccountId)
                : _buildCollapsedWalletHeader(l10n, wallet, displayName),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 16), child: MenuDivider()),
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
                style: text.amountRow.copyWith(color: colors.textContent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(_walletBalanceText(l10n, wallet), style: text.body.copyWith(color: colors.textMuted2)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.accountsScreenAccountCount(wallet.accountCount),
          style: text.caption.copyWith(color: colors.textMuted2),
        ),
        const SizedBox(width: 4),
        QuantusIcon(QuantusIcons.caretDown, color: colors.textMuted),
      ],
    );
  }

  Widget _buildExpandedWalletHeader(AppLocalizations l10n, WalletGroup wallet, String? activeAccountId) {
    return Row(
      children: [
        Expanded(child: _buildWalletNameAndEdit(l10n, wallet)),
        if (_containsAccount(wallet, activeAccountId)) ...[
          _ActiveWalletTag(label: l10n.accountsScreenActiveWallet),
          const SizedBox(width: 8),
        ],
        RotatedBox(quarterTurns: 2, child: QuantusIcon(QuantusIcons.caretDown, color: context.colorsV3.textMuted)),
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
      trailing: _MenuKebab(onTap: () => _openAccountMenu(account)),
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
      trailing: _MenuKebab(onTap: () => _openMultisigAccountMenu(account)),
    );
  }
}

/// Trailing kebab on an account row: opens the account menu, while tapping
/// the row itself switches to the account.
class _MenuKebab extends StatelessWidget {
  final VoidCallback onTap;

  const _MenuKebab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    const size = 36.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.bgVoid,
          shape: BoxShape.circle,
          border: Border.all(color: colors.borderHairline),
        ),
        child: QuantusIcon(QuantusIcons.kebab, color: colors.textContent),
      ),
    );
  }
}

class _ActiveWalletTag extends StatelessWidget {
  final String label;

  const _ActiveWalletTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return QuantusBadge(label: label, tone: BadgeTone.flare);
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final border = isHighlighted
        ? Border.all(color: colors.accentFlare, width: 2)
        : isActive
        ? Border.all(color: colors.borderHairline)
        : null;
    final hasTitle = title != null && title!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder, border: border),
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
                                  style: text.amountRow.copyWith(color: colors.textContent),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (tag != null) ...[const SizedBox(width: 8), tag!],
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(subtitle, style: text.body.copyWith(color: colors.textMuted2)),
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
