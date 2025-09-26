import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/send/qr_scanner_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/account_details.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/action_button.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/error_display.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/history_section.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class WalletMain extends ConsumerStatefulWidget {
  final String? address;

  const WalletMain({super.key, this.address});

  @override
  ConsumerState<WalletMain> createState() => _WalletMainState();
}

class _WalletMainState extends ConsumerState<WalletMain> {
  final NumberFormattingService _formattingService = NumberFormattingService();
  final ScrollController _scrollController = ScrollController();
  bool _isErrorSheetDisplayed = false;

  @override
  void initState() {
    super.initState();

    if (widget.address != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSharedAddressActionSheet(context, widget.address!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void setIsErrorSheetDisplayed(bool value) {
    _isErrorSheetDisplayed = value;
  }

  @override
  Widget build(BuildContext context) {
    final activeAccountAsync = ref.watch(activeAccountProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final activeAccountTransactionsAsync = ref.watch(
      activeAccountTransactionsProvider,
    );

    if (activeAccountAsync.isLoading) {
      return _createLoadingDisplay(context);
    }

    final hasError = activeAccountAsync.hasError;
    final noAccount = activeAccountAsync.value == null;

    print('error: $hasError, noAccount: $noAccount');

    if ((hasError || noAccount) && !_isErrorSheetDisplayed) {
      setIsErrorSheetDisplayed(true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showErrorDisplaySheet(
          context,
          activeAccountAsync: activeAccountAsync,
          setIsErrorSheetDisplayed: setIsErrorSheetDisplayed,
        );
      });
    }

    final activeAccount = activeAccountAsync.value!;

    return ScaffoldBase(
      dim: 0,
      decorations: [
        Positioned(
          left: context.getHorizontalCenterPosition(252),
          bottom: -30,
          child: const Sphere(variant: 6, size: 252),
        ),
      ],
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
                  const SizedBox(height: 31.0),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            child: SvgPicture.asset(
                              'assets/scan_1.svg',
                              width: context.isTablet ? 29 : 21,
                            ),
                            onTap: () async {
                              final scannedAddress =
                                  await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const QRScannerScreen(),
                                      fullscreenDialog: true,
                                    ),
                                  );

                              if (scannedAddress != null) {
                                Navigator.of(
                                  // ignore: use_build_context_synchronously
                                  context,
                                ).pushNamed('/send', arguments: scannedAddress);
                              }
                            },
                          ),
                          const SizedBox(width: 12.0),
                          InkWell(
                            child: SvgPicture.asset(
                              'assets/wallet_icon.svg',
                              width: context.isTablet ? 32 : 24,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AccountsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AccountDetails(activeAccount: activeAccount),
                      const SizedBox(height: 20),
                      balanceAsync.when(
                        data: (balance) => Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _formattingService.formatBalance(balance),
                                style: context.themeText.extraLargeTitle
                                    ?.copyWith(
                                      color: context.themeColors.light,
                                    ),
                              ),
                              TextSpan(
                                text: ' ${AppConstants.tokenSymbol}',
                                style: context.themeText.smallTitle?.copyWith(
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
                        error: (err, stack) => SizedBox(
                          width: 250,
                          child: Text(
                            textAlign: TextAlign.center,
                            err.toString(),
                            style: context.themeText.detail?.copyWith(
                              color: context.themeColors.textError,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActionButton(
                        type: ActionType.send,
                        onPressed: () {
                          Navigator.pushNamed(context, '/send');
                        },
                      ),
                      const SizedBox(width: 33),
                      ActionButton(
                        type: ActionType.receive,
                        onPressed: () {
                          showReceiveSheet(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: HistorySection(
                allTransactionsAsync: activeAccountTransactionsAsync,
                activeAccount: activeAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createLoadingDisplay(BuildContext context) {
    return ScaffoldBase(
      child: Center(
        child: CircularProgressIndicator(
          color: context.themeColors.circularLoader,
        ),
      ),
    );
  }
}
