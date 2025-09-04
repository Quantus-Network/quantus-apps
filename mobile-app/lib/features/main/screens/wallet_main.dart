import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transactions_list.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/transactions_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/models/combined_transactions_list.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/utils/transaction_utils.dart';

class WalletMain extends ConsumerStatefulWidget {
  const WalletMain({super.key});

  @override
  ConsumerState<WalletMain> createState() => _WalletMainState();
}

class _WalletMainState extends ConsumerState<WalletMain> {
  final NumberFormattingService _formattingService = NumberFormattingService();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildActionButton({
    required Widget iconWidget,
    required String label,
    required Color borderColor,
    required VoidCallback onPressed,
    bool disabled = false,
  }) {
    final color = disabled ? Colors.white.useOpacity(0.5) : Colors.white;
    final bgColor = Colors.black.useOpacity(166 / 255.0);
    final effectiveBorderColor = disabled
        ? borderColor.useOpacity(0.5)
        : borderColor;

    Widget finalIconWidget = iconWidget;
    if (iconWidget is SvgPicture) {
      finalIconWidget = SvgPicture.asset(
        (iconWidget.bytesLoader as SvgAssetLoader).assetName,
        width: context.themeSize.mainMenuWidth,
        height: context.themeSize.mainMenuHeight,
      );
    } else if (iconWidget is Icon) {
      finalIconWidget = Icon(
        iconWidget.icon,
        color: color,
        size: context.themeSize.mainMenuHeight,
      );
    } else if (iconWidget is Image) {
      finalIconWidget = SizedBox(
        width: context.themeSize.mainMenuWidth,
        height: context.themeSize.mainMenuHeight,
        child: iconWidget,
      );
    }

    return Opacity(
      opacity: disabled ? 0.7 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: context.isTablet ? 105 : 65,
          height: context.isTablet ? 96 : 56,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: ShapeDecoration(
            color: bgColor,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1, color: effectiveBorderColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              finalIconWidget,
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.themeText.tag,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(
    AsyncValue<CombinedTransactionsList> allTransactionsAsync,
    Account activeAccount,
  ) {
    return allTransactionsAsync.when(
      data: (combinedData) {
        // Combine and deduplicate all transaction types
        final allTransactions =
            TransactionUtils.combineAndDeduplicateTransactions(
              pendingTransactions: combinedData.pendingTransactions,
              reversibleTransfers: combinedData.reversibleTransfers,
              otherTransfers: combinedData.otherTransfers,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10.0, bottom: 10.0),
              child: Text(
                'Recent Transactions',
                style: context.themeText.smallParagraph?.copyWith(
                  color: context.themeColors.light,
                ),
              ),
            ),
            if (allTransactionsAsync.isRefreshing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: LinearProgressIndicator()),
              ),
            RecentTransactionsList(
              transactions: allTransactions.take(4).toList(),
              accountIds: [activeAccount.accountId],
            ),
            if (allTransactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0, right: 12.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionsScreen(
                            showAccountFilter: false,
                            fixedAccountId: activeAccount.accountId,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Transaction History →',
                      style: context.themeText.detail?.copyWith(
                        color: context.themeColors.textPrimary.useOpacity(0.80),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: Colors.black.withAlpha(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0CE6ED)),
            ),
          ),
        ),
      ),
      error: (error, stack) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: Colors.black.withAlpha(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error.toString(),
                style: context.themeText.smallParagraph?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    ref.invalidate(activeAccountTransactionsProvider),
                child: Text('Retry', style: context.themeText.smallParagraph),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAccountAsync = ref.watch(activeAccountProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final activeAccountTransactionsAsync = ref.watch(
      activeAccountTransactionsProvider,
    );

    if (activeAccountAsync.isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: context.themeColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: context.themeColors.circularLoader,
          ),
        ),
      );
    }

    final hasError = activeAccountAsync.hasError;
    final noAccount = activeAccountAsync.value == null;

    print('error: $hasError, noAccount: $noAccount');

    if (hasError || noAccount) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: context.themeColors.background,
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: context.themeColors.error,
                        size: 50,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Failed to Connect',
                        style: context.themeText.smallTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activeAccountAsync.error?.toString() ??
                            'Could not load wallet data. Please check your '
                                'network connection and try again.',
                        style: context.themeText.smallParagraph?.copyWith(
                          color: context.themeColors.textPrimary.useOpacity(
                            0.7,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFullWidthActionButton(
                    label: 'Retry',
                    onTap: () {
                      ref.invalidate(activeAccountProvider);
                      ref.invalidate(balanceProvider);
                      ref.invalidate(activeAccountTransactionsProvider);
                    },
                    gradient: const LinearGradient(
                      begin: Alignment(0.50, 0.00),
                      end: Alignment(0.50, 1.00),
                      colors: [Color(0xFF0CE6ED), Color(0xFF8AF9A8)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final activeAccount = activeAccountAsync.value!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: RefreshIndicator(
              onRefresh: () async {
                // Refresh balances with loading indicator
                final activeAccount = ref.read(activeAccountProvider).value;
                if (activeAccount != null) {
                  ref.invalidate(balanceProviderFamily);
                  // Trigger a loading refresh on the filtered controller
                  // used by active transactions
                  await ref
                      .read(
                        filteredPaginationControllerProviderFamily(
                          AccountIdListCache.get([activeAccount.accountId]),
                        ).notifier,
                      )
                      .loadingRefresh();
                }
                ref.invalidate(balanceProviderRaw);
                // Invalidate combined active account provider to recompute
                ref.invalidate(activeAccountTransactionsProvider);
              },
              color: const Color(0xFF0CE6ED),
              backgroundColor: Colors.black,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/logo/logo.svg',
                                  height: context.isTablet ? 45 : 25,
                                ),
                                const SizedBox(width: 9.0),
                                SvgPicture.asset(
                                  'assets/logo/logo-name.svg',
                                  height: context.isTablet ? 35.6 : 15.6,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: SvgPicture.asset(
                                    'assets/wallet_icon.svg',
                                    width: context.isTablet ? 32 : 24,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AccountsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AccountsScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/active_dot.png',
                                      width: context.isTablet ? 28 : 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      activeAccount.name,
                                      style: context.themeText.smallParagraph,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white70,
                                      size: context.isTablet ? 18 : 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            balanceAsync.when(
                              data: (balance) => Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _formattingService.formatBalance(
                                        balance,
                                      ),
                                      style: context.themeText.extraLargeTitle
                                          ?.copyWith(
                                            color: context.themeColors.light,
                                          ),
                                    ),
                                    TextSpan(
                                      text: ' ${AppConstants.tokenSymbol}',
                                      style: context.themeText.smallTitle
                                          ?.copyWith(
                                            color: context.themeColors.light,
                                          ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              loading: () => CircularProgressIndicator(
                                color: context.themeColors.circularLoader,
                              ),
                              error: (err, stack) => Text(
                                'Error',
                                style: TextStyle(
                                  color: context.themeColors.textError,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Row(
                          spacing: context.isTablet ? 28 : 0,
                          mainAxisAlignment: context.isTablet
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActionButton(
                              iconWidget: SvgPicture.asset(
                                'assets/send_icon_1.svg',
                                width: 19,
                              ),
                              label: 'SEND',
                              borderColor: const Color(0xFF0AD4F6),
                              onPressed: () {
                                Navigator.pushNamed(context, '/send');
                              },
                            ),
                            _buildActionButton(
                              iconWidget: SvgPicture.asset(
                                'assets/receive_icon_1.svg',
                                width: 19,
                              ),
                              label: 'RECEIVE',
                              borderColor: const Color(0xFFB258F1),
                              onPressed: () {
                                showReceiveSheet(context);
                              },
                            ),
                            _buildActionButton(
                              iconWidget: SvgPicture.asset(
                                'assets/swap_icon_1.svg',
                                width: 19,
                              ),
                              label: 'SWAP',
                              borderColor: const Color(0xFF0AD4F6),
                              onPressed: () {},
                              disabled: true,
                            ),
                            _buildActionButton(
                              iconWidget: SvgPicture.asset(
                                'assets/bridge_icon.svg',
                                width: 19,
                              ),
                              label: 'BRIDGE',
                              borderColor: const Color(0xFF0AD4F6),
                              onPressed: () {},
                              disabled: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildHistorySection(
                      activeAccountTransactionsAsync,
                      activeAccount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthActionButton({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          gradient: gradient,
          color: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Center(
          child: Text(
            label,
            style: context.themeText.smallTitle?.copyWith(
              color: context.themeColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
